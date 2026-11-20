import Foundation
import SwiftUI
import Testing

@testable import Textual

struct MarkdownFormatterTests {
  private func markdown(_ source: String) throws -> String {
    try Formatter(NSAttributedString(markdown: source)).markdown()
  }

  @Test(arguments: [
    "A plain paragraph.",
    "First paragraph.\n\nSecond paragraph.",
    "# Heading 1\n\n## Heading 2\n\n### Heading 3",
    "Some **bold**, *italic* and ~~struck~~ words.",
    "**bold *both* bold** and `code` here",
    "A [link](https://example.com/a_b) in text.",
    "- First item\n- Second item\n  - Nested item\n- Third item",
    "1. First\n2. Second\n   - Nested\n3. Third",
    "> A quote\n>\n> in two paragraphs",
    "```swift\nlet x = 1\nlet y = 2\n```",
    "Above\n\n---\n\nBelow",
    "| Name | Count |\n| --- | --: |\n| a | 1 |\n| b | 2 |",
  ])
  func writesBackTheMarkdownItWasMadeFrom(source: String) throws {
    #expect(try markdown(source) == source)
  }

  @Test func spacesAtTheEndsOfAStyledRunGoOutsideItsMarkers() throws {
    // given
    var text = AttributedString("a ")
    var bold = AttributedString(" bold ")
    bold.inlinePresentationIntent = .stronglyEmphasized
    text += bold
    text += AttributedString("b")
    text.presentationIntent = PresentationIntent(.paragraph, identity: 1)

    // when
    let result = Formatter(text).markdown()

    // then
    #expect(result == "a  **bold** b")
  }

  @Test func symbolsThatWouldStartAStyleAreEscaped() throws {
    #expect(try markdown("2\\*3\\*4 and snake_case and \\_x\\_") == "2\\*3\\*4 and snake_case and \\_x\\_")
    #expect(try markdown("\\# not a heading") == "\\# not a heading")
    #expect(try markdown("1\\. not a list") == "1\\. not a list")
  }

  @Test func codeWithBackticksGetsALongerFence() throws {
    #expect(try markdown("Run ``a`b`` now") == "Run ``a`b`` now")
    #expect(try markdown("````\n```\ninner\n```\n````") == "````\n```\ninner\n```\n````")
  }

  @Test(arguments: [
    "a\\\n\\- b",
    "a\\\n\\+ b",
    "a\\\n\\# b",
    "a\\\n\\> b",
    "a\\\n1\\. b",
    "a\\\n\\===",
    "a\\\n\\--",
    "- a\\\n  \\- b",
  ])
  func lineAfterALineBreakStaysInTheParagraph(source: String) throws {
    #expect(try markdown(source) == source)
  }

  @Test(arguments: ["\\---", "\\-", "\\+", "2024\\.", "7\\)"])
  func paragraphOfOnlyAMarkerStaysText(source: String) throws {
    #expect(try markdown(source) == source)
  }

  @Test(arguments: [
    "\\<https://example.com>",
    "\\<div> and Vec\\<T> but a < b",
    "\\&copy; and \\&#169; but AT&T",
    "\\~\\~not struck\\~\\~ and \\~200 ms",
  ])
  func symbolsThatWouldStartHTMLOrStrikethroughAreEscaped(source: String) throws {
    #expect(try markdown(source) == source)
  }

  @Test func nestedListStartingAfterOneGetsAnEmptyLineAboveIt() throws {
    #expect(try markdown("- a\n\n  3. x\n  4. y") == "- a\n\n  3. x\n  4. y")
  }

  @Test func adjacentListsKeepDifferentMarkers() throws {
    #expect(try markdown("- a\n\n* b") == "- a\n\n* b")
    #expect(try markdown("1. a\n\n1) b") == "1. a\n\n1) b")
  }

  @Test func linkWithAnUnbalancedParenthesisHasItsAddressInAngleBrackets() throws {
    #expect(try markdown("[w](<https://x.com/a)b>)") == "[w](<https://x.com/a)b>)")
    #expect(
      try markdown("[w](https://en.wikipedia.org/wiki/A_(b))")
        == "[w](https://en.wikipedia.org/wiki/A_(b))")
  }

  @Test func headingEndingInANumberSignKeepsIt() throws {
    #expect(try markdown("# Use \\#") == "# Use \\#")
  }

  @Test func codeWithASpaceAtBothEndsKeepsThem() throws {
    #expect(try markdown("Run `  a  ` now") == "Run `  a  ` now")
  }

  @Test func attachmentTextIsEscapedExceptMath() throws {
    // given
    var text = AttributedString(
      "\u{FFFC}",
      attributes: AttributeContainer().attachment(.init(TextAttachment(description: "a*b")))
    )
    text += AttributedString(
      "\u{FFFC}",
      attributes: AttributeContainer().attachment(
        .init(MathAttachment(latex: "x*y", style: .inline)))
    )
    text.presentationIntent = PresentationIntent(.paragraph, identity: 1)

    // when
    let result = Formatter(text).markdown()

    // then
    #expect(result == "a\\*b$x*y$")
  }
}

/// An attachment that shows only text, like an image's alt text.
private struct TextAttachment: Textual.Attachment {
  var description: String

  var body: some View {
    Text(description)
  }

  func sizeThatFits(_: ProposedViewSize, in _: TextEnvironmentValues) -> CGSize {
    .zero
  }
}
