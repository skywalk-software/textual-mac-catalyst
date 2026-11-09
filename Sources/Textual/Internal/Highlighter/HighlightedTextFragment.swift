import SwiftUI

// MARK: - Overview
//
// HighlightedTextFragment displays syntax-highlighted code using a two-phase approach.
// Tokenization runs asynchronously and is keyed by content, while highlighting runs
// synchronously on token or environment changes (theme, color scheme, dynamic type).
//
// The presentationIntent is preserved after highlighting so pasteboard formatters can
// reconstruct the block structure when copying code.
//
// Tokens and highlighted code are @State values, not properties of an @Observable model.
// Observation notifies SwiftUI before a property takes its new value, and SwiftUI can update
// the view inside that notification. It did when an enclosing scroll view had a commit pending:
// the view read the old tokens and was never updated again, so the code stayed unhighlighted.
// @State stores the new value before SwiftUI updates the view.

struct HighlightedTextFragment: View {
  @Environment(\.textEnvironment) private var textEnvironment

  @State private var tokens: [CodeToken] = []
  @State private var highlightedCode: AttributedString?

  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  init(
    _ content: AttributedSubstring,
    languageHint: String?,
    theme: StructuredText.HighlighterTheme
  ) {
    self.content = content
    self.languageHint = languageHint
    self.theme = theme
  }

  var body: some View {
    TextFragment(highlightedCode ?? AttributedString(content))
      .foregroundStyle(theme.foregroundColor)
      .task(id: content) {
        let code = String(content.characters[...])
        tokens = [CodeToken(content: code, type: .plain)]

        if let tokenizer = CodeTokenizer.shared, let languageHint {
          tokens = await tokenizer.tokenize(code: code, language: languageHint)
        }
      }
      .onChange(of: Tuple(tokens, textEnvironment)) { _, newValue in
        highlightedCode = Self.highlightedCode(
          tokens: newValue.values.0,
          presentationIntent: content.presentationIntent,
          using: theme,
          environment: newValue.values.1
        )
      }
  }
}

extension HighlightedTextFragment {
  static func highlightedCode(
    tokens: [CodeToken],
    presentationIntent: PresentationIntent?,
    using theme: StructuredText.HighlighterTheme,
    environment: TextEnvironmentValues
  ) -> AttributedString {
    var attributes = AttributeContainer()
    // Re-apply the presentation intent for pasteboard formatters
    attributes.presentationIntent = presentationIntent
    ForegroundColorProperty(theme.foregroundColor)
      .apply(in: &attributes, environment: environment)
    var highlightedCode = AttributedString()

    for token in tokens {
      var content = AttributedString(token.content)
      var tokenAttributes = attributes

      if let tokenProperties = theme.tokenProperties[token.type] {
        tokenProperties.apply(in: &tokenAttributes, environment: environment)
      }

      content.mergeAttributes(tokenAttributes)
      highlightedCode.append(content)
    }

    return highlightedCode
  }
}
