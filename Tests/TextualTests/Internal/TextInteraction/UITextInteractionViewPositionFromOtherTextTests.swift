#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SwiftUI
  import Testing
  import UIKit

  @testable import Textual

  // APP-1416: UIKit passed the view a position that its text has no run slice for, and looking up
  // that position's rectangle stopped the app.
  @MainActor
  struct UITextInteractionViewPositionFromOtherTextTests {
    @Test func caretRectIsZeroForAPositionFromOtherText() throws {
      // given
      let view = try makeView(fixtureName: "empty")
      let position = try positionInSecondParagraph()

      // when
      let caretRect = view.caretRect(for: position)

      // then
      #expect(caretRect == .zero)
    }

    @Test(arguments: [
      IndexPath(runSlice: 0, run: 0, line: 0, layout: 2),
      IndexPath(runSlice: 0, run: 0, line: 99, layout: 1),
      IndexPath(runSlice: 0, run: 99, line: 0, layout: 1),
      IndexPath(runSlice: 99, run: 0, line: 0, layout: 1),
    ])
    func caretRectIsZeroForAPositionPastTheEndOfLongerText(indexPath: IndexPath) throws {
      // given
      let view = try makeView(fixtureName: "two-paragraphs-bidi")
      let position = TextPositionBox(TextPosition(indexPath: indexPath, affinity: .downstream))

      // when
      let caretRect = view.caretRect(for: position)

      // then
      #expect(caretRect == .zero)
    }

    @Test func rangeFromOtherTextHasNoRectsOrText() throws {
      // given
      let view = try makeView(fixtureName: "empty")
      let range = try rangeAcrossBothParagraphs()

      // then
      #expect(view.firstRect(for: range) == .zero)
      #expect(view.selectionRects(for: range).isEmpty)
      #expect(view.text(in: range) == nil)
      #expect(view.attributedText(in: range).length == 0)
      #expect(view.closestPosition(to: .zero, within: range) == nil)
    }

    @Test func positionFromOtherTextHasNoOffsetOrBoundary() throws {
      // given
      let view = try makeView(fixtureName: "empty")
      let position = try positionInSecondParagraph()

      // then
      #expect(view.position(from: position, offset: 1) == nil)
      #expect(view.offset(from: view.beginningOfDocument, to: position) == 0)
      #expect(!view.isPosition(position, atBoundary: .word, inDirection: .storage(.forward)))
      #expect(!view.isPosition(position, withinTextUnit: .word, inDirection: .storage(.forward)))
    }

    @Test func selectingARangeFromOtherTextSelectsNothing() throws {
      // given
      let view = try makeView(fixtureName: "empty")

      // when
      view.selectedTextRange = try rangeAcrossBothParagraphs()

      // then
      #expect(view.model.selectedRange == nil)
    }

    @Test func positionInTheViewsOwnTextKeepsItsCaretRect() throws {
      // given
      let view = try makeView(fixtureName: "two-paragraphs-bidi")
      let position = try positionInSecondParagraph()

      // when
      let caretRect = view.caretRect(for: position)

      // then
      #expect(caretRect.height > 0)
    }

    private func makeView(fixtureName: String) throws -> UITextInteractionView {
      UITextInteractionView(
        model: try TextSelectionModel(fixtureName: fixtureName),
        overflowRegions: [],
        openURL: OpenURLAction { _ in .discarded }
      )
    }

    private func positionInSecondParagraph() throws -> TextPositionBox {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      try #require(model.endPosition.indexPath.layout == 1)
      return TextPositionBox(model.endPosition)
    }

    private func rangeAcrossBothParagraphs() throws -> TextRangeBox {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      return TextRangeBox(TextRange(start: model.startPosition, end: model.endPosition))
    }
  }
#endif
