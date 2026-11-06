#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import Foundation
  import Testing
  import UniformTypeIdentifiers

  @testable import Textual

  struct PasteboardItemsTests {
    // APP-1347: Copy put plain text under public.plain-text, which Mac apps don't read as text, so
    // Command-C on Mac Catalyst left Mac apps nothing to paste.
    @Test func plainTextUsesTheTypeMacAppsRead() throws {
      // given
      let formatter = try Formatter(NSAttributedString(markdown: "Copy **this** text."))

      // when
      let items = formatter.pasteboardItems()

      // then
      #expect(items.count == 1)
      #expect(items.first?[UTType.utf8PlainText.identifier] as? String == "Copy this text.")
      #expect(items.first?[UTType.plainText.identifier] == nil)
      #expect(items.first?[UTType.html.identifier] as? String == formatter.html())
    }
  }
#endif
