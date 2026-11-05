import SwiftUI
@_spi(Textual) private import SwiftUIMath

struct MathAttachment: Attachment {
  enum DisplayStyle: Sendable {
    case inline
    case block
  }

  var description: String {
    switch displayStyle {
    case .inline:
      return "$\(latex)$"
    case .block:
      return "$$\(latex)$$"
    }
  }

  var selectionStyle: AttachmentSelectionStyle {
    .text
  }

  let latex: String
  let displayStyle: DisplayStyle

  init(latex: String, style: DisplayStyle) {
    self.latex = latex
    self.displayStyle = style
  }

  var body: some View {
    MathView(latex: latex, style: displayStyle)
  }

  func baselineOffset(in environment: TextEnvironmentValues) -> CGFloat {
    -typographicBounds(in: environment).descent
  }

  func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
    var bounds = typographicBounds(fitting: proposal, in: environment)
    guard let width = proposal.width else {
      return bounds.size
    }

    // While looking for a better line break, SwiftUIMath lets a line run up to 30% past the width
    // it was given, so ask for less until the formula fits. SwiftUIMath rounds widths to the half
    // point, so half a point over counts as fitting. A piece too wide to break stays wide.
    var fittingWidth = width
    for _ in 0..<3 where bounds.width > width + 0.5 {
      fittingWidth -= bounds.width - width
      guard fittingWidth > 0 else {
        break
      }
      let narrowerBounds = typographicBounds(
        fitting: .init(width: fittingWidth, height: proposal.height),
        in: environment
      )
      if narrowerBounds.width < bounds.width {
        bounds = narrowerBounds
      }
    }

    return bounds.size
  }

  private func typographicBounds(
    fitting proposal: ProposedViewSize = .unspecified,
    in environment: TextEnvironmentValues
  ) -> Math.TypographicBounds {
    Math.typographicBounds(
      for: latex,
      fitting: proposal,
      font: .init(
        name: .init(environment.mathProperties.fontName),
        size: FontScaled(environment.mathProperties.fontScale).resolve(in: environment)
      ),
      style: .init(displayStyle)
    )
  }
}

private struct MathView: View {
  @Environment(\.textEnvironment) private var environment

  let latex: String
  let style: MathAttachment.DisplayStyle

  var body: some View {
    Math(latex)
      .mathFont(
        .init(
          name: .init(environment.mathProperties.fontName),
          size: FontScaled(environment.mathProperties.fontScale).resolve(in: environment)
        )
      )
      .mathTypesettingStyle(.init(style))
      .mathRenderingMode(.monochrome)
  }
}

extension Math.Font.Name {
  fileprivate init(_ fontName: MathProperties.FontName) {
    self.init(rawValue: fontName.rawValue)
  }
}

extension Math.TypesettingStyle {
  fileprivate init(_ style: MathAttachment.DisplayStyle) {
    switch style {
    case .inline:
      self = .text
    case .block:
      self = .display
    }
  }
}
