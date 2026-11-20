import Foundation

/// Text in the forms that Copy writes: plain text, HTML and Markdown.
///
/// Copy and Copy as Markdown write these for the text selected in a ``StructuredText``. To copy
/// all of a view's text without a selection, as a Copy button under it would, make one from the
/// view's markup and parser:
///
/// ```swift
/// let text = try PasteboardText(markdown, parser: .markdown())
/// UIPasteboard.general.setItems(text.pasteboardItems)
/// ```
///
/// Images are written as their alt text, since a view loads them only when it draws them.
public struct PasteboardText {
  private let formatter: Formatter

  /// Creates the text by parsing `markup` with `parser`, as ``StructuredText`` does.
  @MainActor
  public init(_ markup: String, parser: any MarkupParser) throws {
    let attributedString = try parser.attributedString(for: markup)
    formatter = Formatter(attributedString.removingCodeBlockLastLineBreaks())
  }

  /// The text with no styles, the way Copy writes it for apps that take only plain text.
  public var plainText: String {
    formatter.plainText()
  }

  /// The text as HTML, the way Copy writes it for apps that paste styled text.
  public var html: String {
    formatter.html()
  }

  /// The text as Markdown, the way Copy as Markdown writes it.
  public var markdown: String {
    formatter.markdown()
  }
}

extension AttributedString {
  /// The text without the line break at the end of each code block, which `CodeBlock` doesn't draw,
  /// so it isn't in the text that Copy takes from the view either.
  fileprivate func removingCodeBlockLastLineBreaks() -> AttributedString {
    var text = self
    let lineBreakOffsets = runs[\.presentationIntent].compactMap { intent, range -> Int? in
      guard
        intent?.components.contains(where: \.kind.isCodeBlock) == true,
        let last = characters[range].indices.last, characters[last] == "\n"
      else {
        return nil
      }
      return characters.distance(from: characters.startIndex, to: last)
    }
    for offset in lineBreakOffsets.reversed() {
      let lineBreak = text.characters.index(text.characters.startIndex, offsetBy: offset)
      text.characters.remove(at: lineBreak)
    }
    return text
  }
}

extension PresentationIntent.Kind {
  fileprivate var isCodeBlock: Bool {
    guard case .codeBlock = self else { return false }
    return true
  }
}

#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  extension PasteboardText {
    /// The items Copy puts on `UIPasteboard`: the plain text and the HTML.
    public var pasteboardItems: [[String: Any]] {
      formatter.pasteboardItems()
    }

    /// The items Copy as Markdown puts on `UIPasteboard`: the Markdown as the plain text.
    public var markdownPasteboardItems: [[String: Any]] {
      formatter.markdownPasteboardItems()
    }
  }
#endif
