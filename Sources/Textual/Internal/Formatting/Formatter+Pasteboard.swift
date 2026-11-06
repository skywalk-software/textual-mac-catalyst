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
  }
#endif
