#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import Textual

  @MainActor
  struct CopiedTextStyleTests {
    // APP-1359: Copy built its HTML from the rendered text, which had lost its inline styles, so
    // bold, italic, code, and strikethrough pasted into rich-text apps as plain text.
    @Test func renderedTextKeepsInlineStyles() async {
      // given
      let view = StructuredText(
        markdown: "This has **bold**, *italic*, `code`, and ~~strikethrough~~."
      )
      let expected =
        "<p>This has <strong>bold</strong>, <em>italic</em>, <code>code</code>, and <del>strikethrough</del>.</p>"

      // when
      let html = await copiedHTML(of: view)

      // then
      #expect(html == expected)
    }

    /// Renders `view` and formats all of its text the way Copy does.
    private func copiedHTML(of view: some View) async -> String {
      var renderedText: [NSAttributedString] = []
      let capturingView = view.overlayTextLayoutCollection { layoutCollection in
        renderedText = layoutCollection.layouts.map(\.attributedString)
        return Color.clear
      }

      let image = Snapshotting<AnyView, UIImage>
        .image(layout: .device(config: .iPhoneSe))
        .snapshot(AnyView(capturingView))
      await withCheckedContinuation { continuation in
        image.run { _ in continuation.resume() }
      }

      let copiedText = NSMutableAttributedString()
      renderedText.forEach(copiedText.append)
      return Formatter(copiedText).html()
    }
  }
#endif
