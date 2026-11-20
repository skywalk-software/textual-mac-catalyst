import Foundation

// MARK: - Overview
//
// Writes the block and inline nodes as Markdown, for Copy as Markdown.
//
// The nodes come from the styled text of a selection, not from the Markdown the text was made
// from, so the result reads the same but isn't that source character for character: every
// list uses `-`, every emphasis `*`, and a symbol that would start a style is escaped.

extension Formatter {
  func markdown() -> String {
    blockNodes.renderMarkdown()
  }
}

// MARK: - Inline rendering

/// One run of text, written as Markdown already, with the styles and link around it.
private struct MarkdownRun {
  enum Style: CaseIterable {
    case strong
    case emphasized
    case strikethrough

    var marker: String {
      switch self {
      case .strong:
        return "**"
      case .emphasized:
        return "*"
      case .strikethrough:
        return "~~"
      }
    }
  }

  var text: String
  var styles: Set<Style> = []
  var link: URL?
}

extension Formatter.InlineNode {
  fileprivate func markdownRuns(styles: Set<MarkdownRun.Style> = [], link: URL? = nil)
    -> [MarkdownRun]
  {
    switch self {
    case .text(let text):
      return [.init(text: text.escapingMarkdownSymbols(), styles: styles, link: link)]
    case .code(let code):
      return [.init(text: code.markdownCodeSpan(), styles: styles, link: link)]
    case .strong(let children):
      return children.flatMap { $0.markdownRuns(styles: styles.union([.strong]), link: link) }
    case .emphasized(let children):
      return children.flatMap {
        $0.markdownRuns(styles: styles.union([.emphasized]), link: link)
      }
    case .strikethrough(let children):
      return children.flatMap {
        $0.markdownRuns(styles: styles.union([.strikethrough]), link: link)
      }
    case .link(let url, let children):
      return children.flatMap { $0.markdownRuns(styles: styles, link: url) }
    case .lineBreak:
      // A backslash at the end of a line breaks the line inside a paragraph. It takes no styles,
      // so the markers of a styled run close ahead of it.
      return [.init(text: "\\\n", link: link)]
    case .attachment(let attachment):
      return [.init(text: attachment.description, styles: styles, link: link)]
    }
  }
}

extension Array where Element == Formatter.InlineNode {
  fileprivate func renderMarkdown() -> String {
    let runs = self.flatMap { $0.markdownRuns() }
    var result = ""
    var index = 0
    while index < runs.count {
      let link = runs[index].link
      let end = runs[index...].firstIndex { $0.link != link } ?? runs.count
      let text = runs[index..<end].renderStyledMarkdown()
      if let link {
        result += "[\(text)](\(link.absoluteString))"
      } else {
        result += text
      }
      index = end
    }
    return result
  }
}

extension ArraySlice where Element == MarkdownRun {
  /// The runs with a marker wherever a style starts or ends. Runs next to each other share
  /// their markers, and the spaces at either end of a styled run go outside its markers: a
  /// marker with a space on its inner side doesn't start or end a style.
  fileprivate func renderStyledMarkdown() -> String {
    var result = ""
    var openStyles: [MarkdownRun.Style] = []
    var heldSpaces = ""

    for run in self {
      let leadingSpaces = run.text.prefix(while: \.isWhitespace)
      guard leadingSpaces.count < run.text.count else {
        heldSpaces += run.text
        continue
      }
      let trailingSpaces = String(run.text.reversed().prefix(while: \.isWhitespace).reversed())
      let content = run.text.dropFirst(leadingSpaces.count).dropLast(trailingSpaces.count)

      if let firstToClose = openStyles.firstIndex(where: { !run.styles.contains($0) }) {
        result += openStyles[firstToClose...].reversed().map(\.marker).joined()
        openStyles.removeSubrange(firstToClose...)
      }
      result += heldSpaces + leadingSpaces
      for style in MarkdownRun.Style.allCases
      where run.styles.contains(style) && !openStyles.contains(style) {
        result += style.marker
        openStyles.append(style)
      }
      result += content
      heldSpaces = trailingSpaces
    }
    return result + openStyles.reversed().map(\.marker).joined() + heldSpaces
  }
}

// MARK: - Block rendering

extension Formatter.BlockNode {
  fileprivate var isList: Bool {
    switch self {
    case .orderedList, .unorderedList:
      return true
    default:
      return false
    }
  }

  fileprivate func renderMarkdown() -> String {
    switch self {
    case .paragraph(let children):
      return children.renderMarkdown().escapingMarkdownBlockStart()
    case .header(let level, let children):
      return String(repeating: "#", count: level) + " " + children.renderMarkdown()
    case .orderedList(let children):
      return children.map { $0.renderMarkdown(marker: "\($0.ordinal). ") }
        .joined(separator: "\n")
    case .unorderedList(let children):
      return children.map { $0.renderMarkdown(marker: "- ") }.joined(separator: "\n")
    case .codeBlock(let languageHint, let code):
      // A fence longer than any run of backticks in the code, so none of them ends the block.
      let fence = String(repeating: "`", count: Swift.max(3, code.longestBacktickRun() + 1))
      let lines = code.hasSuffix("\n") ? String(code.dropLast()) : code
      return "\(fence)\(languageHint ?? "")\n\(lines)\n\(fence)"
    case .blockQuote(let children):
      return children.renderMarkdown()
        .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        .map { $0.isEmpty ? ">" : "> " + $0 }
        .joined(separator: "\n")
    case .table(let columns, let children):
      return children.renderMarkdown(columns: columns)
    case .thematicBreak:
      return "---"
    }
  }
}

extension Array where Element == Formatter.BlockNode {
  fileprivate func renderMarkdown() -> String {
    self.map { $0.renderMarkdown() }.joined(separator: "\n\n")
  }
}

// MARK: - List rendering

extension Formatter.ListItem {
  /// The item with `marker` ahead of its first line and the lines after it indented to the
  /// marker's width, which is what keeps them in the item. A list nested in the item goes right
  /// under the text above it; any other block needs an empty line ahead of it.
  fileprivate func renderMarkdown(marker: String) -> String {
    var content = ""
    for (index, block) in blocks.enumerated() {
      if index > 0 {
        content += block.isList ? "\n" : "\n\n"
      }
      content += block.renderMarkdown()
    }

    let indentation = String(repeating: " ", count: marker.count)
    let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    return lines.enumerated().map { index, line in
      if index == 0 {
        return marker + line
      }
      return line.isEmpty ? "" : indentation + line
    }
    .joined(separator: "\n")
  }
}

// MARK: - Table rendering

extension Array where Element == Formatter.TableRow {
  /// A pipe table. The first row is the header, as a table has to have one.
  fileprivate func renderMarkdown(columns: [PresentationIntent.TableColumn]) -> String {
    var lines = self.map { row in
      "| " + row.cells.map { $0.renderMarkdownTableCell() }.joined(separator: " | ") + " |"
    }
    guard !lines.isEmpty else { return "" }

    let columnCount = Swift.max(columns.count, self[0].cells.count)
    let delimiters = (0..<columnCount).map { index -> String in
      guard index < columns.count else { return "---" }

      switch columns[index].alignment {
      case .center:
        return ":-:"
      case .right:
        return "--:"
      default:
        return "---"
      }
    }
    lines.insert("| " + delimiters.joined(separator: " | ") + " |", at: 1)
    return lines.joined(separator: "\n")
  }
}

extension Array where Element == Formatter.InlineNode {
  /// A cell is one line, and a pipe in it would end the cell.
  fileprivate func renderMarkdownTableCell() -> String {
    self.renderMarkdown()
      .replacingOccurrences(of: "\\\n", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "|", with: "\\|")
  }
}

// MARK: - Escaping

extension String {
  /// The text with a backslash ahead of each symbol that Markdown would read as the start of a
  /// style, a code span or a link. An underscore between letters or digits starts nothing, so
  /// names like `snake_case` stay as they are.
  fileprivate func escapingMarkdownSymbols() -> String {
    var result = ""
    var previous: Character?
    var rest = self[...]
    while let character = rest.first {
      rest = rest.dropFirst()
      switch character {
      case "\\", "`", "*", "[", "]":
        result.append("\\")
      case "_":
        let isInsideWord =
          (previous?.isLetter == true || previous?.isNumber == true)
          && (rest.first?.isLetter == true || rest.first?.isNumber == true)
        if !isInsideWord {
          result.append("\\")
        }
      default:
        break
      }
      result.append(character)
      previous = character
    }
    return result
  }

  /// A paragraph whose first characters would make it a heading, a quote or a list item, with
  /// a backslash that keeps it a paragraph.
  fileprivate func escapingMarkdownBlockStart() -> String {
    if self.hasPrefix("#") || self.hasPrefix(">") {
      return "\\" + self
    }
    if self.hasPrefix("- ") || self.hasPrefix("+ ") {
      return "\\" + self
    }
    let digits = self.prefix(while: \.isNumber)
    let afterDigits = self.dropFirst(digits.count)
    if !digits.isEmpty, afterDigits.hasPrefix(". ") || afterDigits.hasPrefix(") ") {
      return String(digits) + "\\" + afterDigits
    }
    return self
  }

  /// The code between backticks: more of them than the code has in a row, and a space on each
  /// side when the code starts or ends with one.
  fileprivate func markdownCodeSpan() -> String {
    let fence = String(repeating: "`", count: longestBacktickRun() + 1)
    let padding = (self.hasPrefix("`") || self.hasSuffix("`")) ? " " : ""
    return fence + padding + self + padding + fence
  }

  fileprivate func longestBacktickRun() -> Int {
    var longest = 0
    var current = 0
    for character in self {
      current = (character == "`") ? current + 1 : 0
      longest = Swift.max(longest, current)
    }
    return longest
  }
}
