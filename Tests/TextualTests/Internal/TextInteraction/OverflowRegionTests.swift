#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SwiftUI
  import Testing
  import UIKit

  @testable import Textual

  // APP-1367: a scrolling code block keeps its own selection, so a selection across a reply
  // skipped it and Copy dropped the code.
  @MainActor
  struct OverflowRegionTests {
    private let codeBetweenParagraphs =
      "quebec romeo\n\n```swift\nlet sierra = 42\n```\n\ntango uniform"

    @Test func copyAcrossACodeBlockIncludesIt() async throws {
      // given
      let rendered = try await render(codeBetweenParagraphs)
      let range = TextRange(start: rendered.model.startPosition, end: rendered.model.endPosition)

      // when
      let copied = rendered.model.attributedText(in: range, including: rendered.regions)

      // then
      #expect(
        Formatter(copied).html()
          == "<p>quebec romeo</p>\n<pre><code class=\"language-swift\">let sierra = 42</code></pre>\n<p>tango uniform</p>"
      )
    }

    @Test func selectionAcrossACodeBlockHighlightsIt() async throws {
      // given
      let rendered = try await render(codeBetweenParagraphs)
      let region = try #require(rendered.regions.first)
      let view = makeView(rendered)
      let range = TextRange(start: rendered.model.startPosition, end: rendered.model.endPosition)

      // when
      let rects = view.selectionRects(for: TextRangeBox(range)).map(\.rect)

      // then
      #expect(rects.contains(region.frame))
    }

    @Test func selectionWithinAParagraphLeavesTheCodeBlockOut() async throws {
      // given
      let rendered = try await render(codeBetweenParagraphs)
      let firstBlockStart = TextPosition(indexPath: .init(layout: 0), affinity: .downstream)
      let range = try #require(rendered.model.blockRange(for: firstBlockStart))

      // when
      let copied = rendered.model.attributedText(in: range, including: rendered.regions)

      // then
      #expect(rendered.model.overflowRegions(rendered.regions, in: range).isEmpty)
      #expect(Formatter(copied).html() == "<p>quebec romeo</p>")
    }

    @Test func selectionToTheEndIncludesATrailingCodeBlock() async throws {
      // given
      let rendered = try await render("quebec romeo\n\n```swift\nlet sierra = 42\n```")
      let range = TextRange(start: rendered.model.startPosition, end: rendered.model.endPosition)

      // when
      let copied = rendered.model.attributedText(in: range, including: rendered.regions)

      // then
      #expect(
        Formatter(copied).html()
          == "<p>quebec romeo</p>\n<pre><code class=\"language-swift\">let sierra = 42</code></pre>"
      )
    }

    @Test func draggingDownIntoACodeBlockSelectsPastIt() async throws {
      // given
      let rendered = try await render(codeBetweenParagraphs)
      let region = try #require(rendered.regions.first)
      let view = makeView(rendered)
      let anchor = rendered.model.startPosition
      let inFirstParagraph = try #require(rendered.model.position(from: anchor, offset: 3))
      view.selectedTextRange = TextRangeBox(TextRange(start: anchor, end: anchor))
      view.selectedTextRange = TextRangeBox(TextRange(start: anchor, end: inFirstParagraph))

      // when
      let topOfCodeBlock = CGPoint(x: region.frame.midX, y: region.frame.minY + 2)
      let position = try #require(view.closestPosition(to: topOfCodeBlock) as? TextPositionBox)

      // then
      let secondParagraphStart = TextPosition(indexPath: .init(layout: 1), affinity: .downstream)
      #expect(position.wrappedValue == secondParagraphStart)
      let range = TextRange(start: anchor, end: position.wrappedValue)
      #expect(rendered.model.overflowRegions(rendered.regions, in: range) == [region])
    }

    @Test func draggingUpIntoACodeBlockSelectsPastIt() async throws {
      // given
      let rendered = try await render(codeBetweenParagraphs)
      let region = try #require(rendered.regions.first)
      let view = makeView(rendered)
      let anchor = rendered.model.endPosition
      let inLastParagraph = try #require(rendered.model.position(from: anchor, offset: -3))
      view.selectedTextRange = TextRangeBox(TextRange(start: anchor, end: anchor))
      view.selectedTextRange = TextRangeBox(TextRange(start: inLastParagraph, end: anchor))

      // when
      let bottomOfCodeBlock = CGPoint(x: region.frame.midX, y: region.frame.maxY - 2)
      let position = try #require(view.closestPosition(to: bottomOfCodeBlock) as? TextPositionBox)

      // then
      #expect(position.wrappedValue == rendered.model.position(before: region))
      let range = TextRange(start: position.wrappedValue, end: anchor)
      #expect(rendered.model.overflowRegions(rendered.regions, in: range) == [region])
    }

    @Test func draggingIntoATrailingCodeBlockSelectsToTheEnd() async throws {
      // given
      let rendered = try await render("quebec romeo\n\n```swift\nlet sierra = 42\n```")
      let region = try #require(rendered.regions.first)
      let view = makeView(rendered)
      let anchor = rendered.model.startPosition
      let inParagraph = try #require(rendered.model.position(from: anchor, offset: 3))
      view.selectedTextRange = TextRangeBox(TextRange(start: anchor, end: anchor))
      view.selectedTextRange = TextRangeBox(TextRange(start: anchor, end: inParagraph))

      // when
      let topOfCodeBlock = CGPoint(x: region.frame.midX, y: region.frame.minY + 2)
      let position = try #require(view.closestPosition(to: topOfCodeBlock) as? TextPositionBox)

      // then
      #expect(position.wrappedValue == rendered.model.endPosition)
    }

    private func makeView(
      _ rendered: (model: TextSelectionModel, regions: [OverflowRegion])
    ) -> UITextInteractionView {
      UITextInteractionView(
        model: rendered.model,
        overflowRegions: rendered.regions,
        openURL: OpenURLAction { _ in .discarded }
      )
    }

    private func render(
      _ markdown: String
    ) async throws -> (model: TextSelectionModel, regions: [OverflowRegion]) {
      var regions: [OverflowRegion] = []
      let view = StructuredText(markdown: markdown)
        .overlayPreferenceValue(OverflowRegionKey.self) { value in
          regions = value
          return Color.clear
        }
      let layoutCollection = try #require(
        await view.renderOnce(capturing: CodableTextLayoutCollection.init)
      )
      return (TextSelectionModel(layoutCollection: layoutCollection), regions)
    }
  }
#endif
