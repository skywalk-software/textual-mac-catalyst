import SwiftUI

extension StructuredText {
  struct MathCodeBlock: View {
    @Environment(\.paragraphStyle) private var paragraphStyle
    @Environment(\.mathProperties) private var mathProperties

    private let content: AttributedString
    private let indentationLevel: Int

    init(_ content: AttributedSubstring) {
      let latex = String(content.characters[...])
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let attachment = MathAttachment(latex: latex, style: .block)
      // The code block's intent goes with the formula, or Copy leaves it out of a selection.
      var attributes = AttributeContainer().attachment(.init(attachment))
      attributes.presentationIntent = content.presentationIntent
      self.content = AttributedString("\u{FFFC}", attributes: attributes)
      self.indentationLevel = content.presentationIntent?.indentationLevel ?? 0
    }

    var body: some View {
      let configuration = BlockStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel
      )
      let resolvedStyle = paragraphStyle.resolve(configuration: configuration)

      AnyView(resolvedStyle)
        .layoutValue(key: BlockAlignmentKey.self, value: mathProperties.textAlignment)
    }

    private var label: some View {
      WithInlineStyle(content) {
        TextFragment($0)
      }
    }
  }
}
