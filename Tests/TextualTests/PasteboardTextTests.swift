import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Textual

@MainActor
struct PasteboardTextTests {
  @Test func writesTheMarkupInEachForm() throws {
    // when
    let text = try PasteboardText("Copy **this** text.", parser: .markdown())

    // then
    #expect(text.plainText == "Copy this text.")
    #expect(text.html == "<p>Copy <strong>this</strong> text.</p>")
    #expect(text.markdown == "Copy **this** text.")
  }

  #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
    @Test func pasteboardItemsMatchTheOnesCopyWrites() throws {
      // given
      let markdown = "Copy **this** text."
      let formatter = try Formatter(NSAttributedString(markdown: markdown))

      // when
      let text = try PasteboardText(markdown, parser: .markdown())

      // then
      #expect(
        text.pasteboardItems.first?[UTType.utf8PlainText.identifier] as? String
          == formatter.plainText())
      #expect(text.pasteboardItems.first?[UTType.html.identifier] as? String == formatter.html())
      #expect(
        text.markdownPasteboardItems.first?[UTType.utf8PlainText.identifier] as? String
          == formatter.markdown())
    }
  #endif
}

#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SwiftUI

  extension PasteboardTextTests {
    @Test func matchesCopyOfTheWholeRenderedText() async throws {
      // given
      let markdown = """
        ## Getting started

        Some **bold**, *italic*, `code` and a [link](https://example.com).

        - First item
        - Second item
          1. Nested

        > A quote

        ```swift
        let sierra = 42
        ```

        | Name | Count |
        | --- | --: |
        | a | 1 |

        The end.
        """
      let rendered = try await renderedText(of: StructuredText(markdown: markdown))

      // when
      let text = try PasteboardText(markdown, parser: .markdown())

      // then
      #expect(text.html == Formatter(rendered).html())
      #expect(text.markdown == Formatter(rendered).markdown())
      #expect(text.plainText == Formatter(rendered).plainText())
    }

    /// Renders `view` and returns what Copy takes when all of its text is selected.
    private func renderedText(of view: some View) async throws -> NSAttributedString {
      var regions: [OverflowRegion] = []
      let capturingView = view.overlayPreferenceValue(OverflowRegionKey.self) { value in
        regions = value
        return Color.clear
      }
      let layoutCollection = try #require(
        await capturingView.renderOnce(capturing: CodableTextLayoutCollection.init)
      )
      let model = TextSelectionModel(layoutCollection: layoutCollection)
      let range = TextRange(start: model.startPosition, end: model.endPosition)
      return model.attributedText(in: range, including: regions)
    }
  }
#endif
