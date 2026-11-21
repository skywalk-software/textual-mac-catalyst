import SwiftUI

extension StructuredText {
  struct CodeBlock: View {
    @Environment(\.highlighterTheme) private var highlighterTheme
    @Environment(\.codeBlockStyle) private var codeBlockStyle

    private let content: AttributedSubstring
    private let languageHint: String?

    init(_ content: AttributedSubstring, languageHint: String?) {
      self.content = content.droppingCodeBlockLineBreak()
      self.languageHint = languageHint
    }

    var body: some View {
      let configuration = CodeBlockStyleConfiguration(
        label: .init(
          HighlightedTextFragment(
            content,
            languageHint: languageHint,
            theme: highlighterTheme
          )
        ),
        indentationLevel: indentationLevel,
        languageHint: languageHint,
        codeBlock: .init(content),
        highlighterTheme: highlighterTheme
      )
      let resolvedStyle = codeBlockStyle.resolve(configuration: configuration)

      AnyView(resolvedStyle)
    }

    private var indentationLevel: Int {
      content.presentationIntent?.indentationLevel ?? 0
    }
  }
}
