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
      let view = UITextInteractionView(
        model: rendered.model,
        overflowRegions: rendered.regions,
        openURL: OpenURLAction { _ in .discarded }
      )
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
