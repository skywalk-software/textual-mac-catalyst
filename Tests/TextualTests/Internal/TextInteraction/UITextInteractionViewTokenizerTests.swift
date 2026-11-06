#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SwiftUI
  import Testing
  import UIKit

  @testable import Textual

  // APP-1365: next to a block edge, UIKit's tokenizer returned a word from the neighboring block,
  // and clipping that word to the current block left a backwards or empty range.
  @MainActor
  struct UITextInteractionViewTokenizerTests {
    @Test func noWordBeforeTheStartOfABlock() async throws {
      // given
      let view = try await makeView(markdown: "alpha bravo\n\n(charlie delta)")
      let blockStart = TextPosition(indexPath: .init(layout: 1), affinity: .downstream)

      // when
      let range = view.rangeEnclosingPosition(
        TextPositionBox(blockStart),
        with: .word,
        inDirection: .storage(.backward)
      )

      // then
      #expect(range == nil)
    }

    @Test func noWordAfterTheEndOfABlock() async throws {
      // given
      let view = try await makeView(markdown: "alpha bravo.\n\ncharlie delta")
      let firstBlockStart = TextPosition(indexPath: .init(layout: 0), affinity: .downstream)
      let blockEnd = try #require(view.model.blockEnd(for: firstBlockStart))

      // when
      let range = view.rangeEnclosingPosition(
        TextPositionBox(blockEnd),
        with: .word,
        inDirection: .storage(.forward)
      )

      // then
      #expect(range == nil)
    }

    @Test func wordInsideABlock() async throws {
      // given
      let view = try await makeView(markdown: "alpha bravo\n\n(charlie delta)")
      let blockStart = TextPositionBox(
        TextPosition(indexPath: .init(layout: 1), affinity: .downstream)
      )
      let insideCharlie = try #require(view.position(from: blockStart, offset: 3))

      // when
      let range = view.rangeEnclosingPosition(
        insideCharlie,
        with: .word,
        inDirection: .storage(.forward)
      )

      // then
      #expect(range.flatMap(view.text(in:)) == "charlie")
    }

    private func makeView(markdown: String) async throws -> UITextInteractionView {
      let text = StructuredText(markdown: markdown)
      let layoutCollection = try #require(
        await text.renderOnce(capturing: CodableTextLayoutCollection.init)
      )
      return UITextInteractionView(
        model: TextSelectionModel(layoutCollection: layoutCollection),
        exclusionRects: [],
        openURL: OpenURLAction { _ in .discarded }
      )
    }
  }
#endif
