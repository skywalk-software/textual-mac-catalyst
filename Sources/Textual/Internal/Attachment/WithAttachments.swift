import SwiftUI

// MARK: - Overview
//
// `WithAttachments` resolves attachment references in an `AttributedString`.
//
// Markup parsing keeps some items as URL attributes:
// - `run.imageURL` for images
// - `run.textual.emojiURL` for custom emoji references emitted by pattern expansion
//
// This view asynchronously loads those URLs using the environment-provided attachment loaders and
// writes the resolved attachments back into the attributed string as `Textual.Attachment`
// attributes. The rest of the rendering pipeline treats attachment runs like any other span.
//
// The resolved string is a @State value, not a property of an @Observable model, for the reason
// given in HighlightedTextFragment: SwiftUI can update the view while an observable property is
// still being assigned, and the view would keep showing the unresolved string.

struct WithAttachments<Content: View>: View {
  @Environment(\.imageAttachmentLoader) private var imageAttachmentLoader
  @Environment(\.emojiAttachmentLoader) private var emojiAttachmentLoader
  @Environment(\.colorEnvironment) private var colorEnvironment

  @State private var resolvedAttributedString: AttributedString?

  private let attributedString: AttributedString
  private let content: (AttributedString) -> Content

  init(
    _ attributedString: AttributedString,
    @ViewBuilder content: @escaping (AttributedString) -> Content
  ) {
    self.attributedString = attributedString
    self.content = content
  }

  var body: some View {
    content(resolvedAttributedString ?? attributedString)
      .task(id: attributedString) {
        let resolved = await Self.resolvingAttachments(
          in: attributedString,
          imageAttachmentLoader: imageAttachmentLoader,
          emojiAttachmentLoader: emojiAttachmentLoader,
          environment: colorEnvironment
        )
        if let resolved {
          resolvedAttributedString = resolved
        }
      }
  }
}

extension WithAttachments {
  /// Returns `attributedString` with its image and emoji URLs loaded as attachments, or `nil`
  /// when it has none to load.
  static func resolvingAttachments(
    in attributedString: AttributedString,
    imageAttachmentLoader: any AttachmentLoader,
    emojiAttachmentLoader: any AttachmentLoader,
    environment: ColorEnvironmentValues
  ) async -> AttributedString? {
    guard attributedString.containsValues(for: [\.imageURL, \.textual.emojiURL]) else {
      return nil
    }

    var attachments: [AnyAttachment] = []
    var ranges: [Range<AttributedString.Index>] = []

    await withTaskGroup(
      of: (AnyAttachment?, Range<AttributedString.Index>).self
    ) { group in
      for run in attributedString.runs {
        if let imageURL = run.imageURL {
          group.addTask {
            let attachment = try? await imageAttachmentLoader.attachment(
              for: imageURL,
              text: String(attributedString[run.range].characters[...]),
              environment: environment
            )
            return (attachment.map(AnyAttachment.init), run.range)
          }
        } else if let emojiURL = run.textual.emojiURL {
          group.addTask {
            let attachment = try? await emojiAttachmentLoader.attachment(
              for: emojiURL,
              text: String(attributedString[run.range].characters[...]),
              environment: environment
            )
            return (attachment.map(AnyAttachment.init), run.range)
          }
        }
      }

      for await (attachment, range) in group {
        guard let attachment else { continue }

        attachments.append(attachment)
        ranges.append(range)
      }
    }

    var resolvedAttributedString = attributedString

    for (range, attachment) in zip(ranges, attachments) {
      resolvedAttributedString[range].textual.attachment = attachment
    }

    return resolvedAttributedString
  }
}
