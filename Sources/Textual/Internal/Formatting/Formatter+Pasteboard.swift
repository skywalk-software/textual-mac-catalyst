#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import UniformTypeIdentifiers

  extension Formatter {
    /// The plain-text and HTML items that Copy puts on `UIPasteboard`.
    ///
    /// Plain text goes under `public.utf8-plain-text`, the type AppKit reads as a string. Mac
    /// Catalyst hands item types to the Mac pasteboard unchanged, so Mac apps find no text under
    /// `public.plain-text`.
    func pasteboardItems() -> [[String: Any]] {
      [
        [
          UTType.utf8PlainText.identifier: plainText(),
          UTType.html.identifier: html(),
        ]
      ]
    }

    /// The type the Markdown goes under beside the plain text, for apps that ask for Markdown.
    static let markdownPasteboardType = "net.daringfireball.markdown"

    /// The items that Copy as Markdown puts on `UIPasteboard`: the Markdown as the plain text,
    /// with no HTML beside it, so every app pastes the symbols.
    func markdownPasteboardItems() -> [[String: Any]] {
      let markdown = markdown()
      return [
        [
          UTType.utf8PlainText.identifier: markdown,
          Self.markdownPasteboardType: Data(markdown.utf8),
        ]
      ]
    }
  }
#endif
