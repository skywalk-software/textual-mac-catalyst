import SwiftUI
import Testing

@testable import Textual

struct MathAttachmentTests {
  private let attachment = MathAttachment(
    latex: "a^3 - b^3 = (a-b)(a^2 + ab + b^2)", style: .inline)
  private let environment = TextEnvironmentValues()

  // APP-1270: swiftui-math can let a broken line run up to 30% past the width it was given, which a
  // table cell then cut off (here, the minus before "ab").
  @Test(arguments: [174, 150, 120])
  func brokenFormulaFitsTheProposedWidth(width: CGFloat) {
    let narrowestSize = attachment.sizeThatFits(.init(width: 1, height: nil), in: environment)

    let size = attachment.sizeThatFits(.init(width: width, height: nil), in: environment)

    // SwiftUIMath rounds widths to the half point.
    #expect(size.width <= max(width, narrowestSize.width) + 0.5)
  }

  @Test func formulaKeepsItsNaturalWidthWhenItFits() {
    let naturalSize = attachment.sizeThatFits(.unspecified, in: environment)

    let size = attachment.sizeThatFits(.init(width: 400, height: nil), in: environment)

    #expect(size == naturalSize)
  }
}
