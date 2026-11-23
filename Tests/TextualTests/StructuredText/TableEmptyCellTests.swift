#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SwiftUI
  import Testing

  @testable import Textual

  // APP-1578: the parser writes nothing for an empty cell, so the cells after it were drawn one
  // column to the left, under the wrong header.
  @MainActor
  struct TableEmptyCellTests {
    @Test func cellsAfterAnEmptyCellStayUnderTheirHeaders() async throws {
      // given
      let markdown = """
        | Alpha | Bravo | Charlie |
        | --- | --- | --- |
        | delta |  | foxtrot |
        |  | hotel | india |
        """

      // when
      let frames = try #require(
        await StructuredText(markdown: markdown).renderOnce { layoutCollection in
          Dictionary(
            layoutCollection.layouts.map { ($0.attributedString.string, $0.frame) },
            uniquingKeysWith: { first, _ in first }
          )
        }
      )

      // then
      let column = { (text: String) in try #require(frames[text]).minX }
      #expect(try column("delta") == column("Alpha"))
      #expect(try column("foxtrot") == column("Charlie"))
      #expect(try column("hotel") == column("Bravo"))
      #expect(try column("india") == column("Charlie"))
    }
  }
#endif
