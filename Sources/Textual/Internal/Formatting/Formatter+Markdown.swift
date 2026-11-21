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
      // Math keeps its dollar signs; any other attachment writes text, like an image's alt text.
      let text =
        (attachment.base is MathAttachment)
        ? attachment.description : attachment.description.escapingMarkdownSymbols()
      return [.init(text: text, styles: styles, link: link)]
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
        result += "[\(text)](\(link.markdownLinkDestination))"
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
  /// Whether a list in a list item can go right under the item's text. A numbered list can start
  /// right under text only when it starts at 1.
  fileprivate var canFollowTextDirectly: Bool {
    switch self {
    case .unorderedList:
      return true
    case .orderedList(let children):
      return children.first?.ordinal == 1
    default:
      return false
    }
  }

  fileprivate func isSameKindOfList(as other: Self) -> Bool {
    switch (self, other) {
    case (.orderedList, .orderedList), (.unorderedList, .unorderedList):
      return true
    default:
      return false
    }
  }

  /// The block as Markdown. A list with `usesSecondMarker` set uses `*` or `)` instead of `-` or
  /// `.`, so it doesn't carry on a list of the same kind right above it.
  fileprivate func renderMarkdown(usesSecondMarker: Bool = false) -> String {
    switch self {
    case .paragraph(let children):
      // Each line after a line break can start a block too.
      return children.renderMarkdown()
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).escapingMarkdownBlockStart() }
        .joined(separator: "\n")
    case .header(let level, let children):
      return String(repeating: "#", count: level) + " "
        + children.renderMarkdown().escapingClosingNumberSigns()
    case .orderedList(let children):
      let delimiter = (usesSecondMarker) ? ")" : "."
      return children.map { $0.renderMarkdown(marker: "\($0.ordinal)\(delimiter) ") }
        .joined(separator: "\n")
    case .unorderedList(let children):
      let marker = (usesSecondMarker) ? "* " : "- "
      return children.map { $0.renderMarkdown(marker: marker) }.joined(separator: "\n")
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
  /// The blocks with an empty line between them. In a list item, a list that can go right under
  /// the item's text goes there instead.
  fileprivate func renderMarkdown(isInListItem: Bool = false) -> String {
    var result = ""
    var usesSecondMarker = false
    for (index, block) in self.enumerated() {
      if index > 0 {
        usesSecondMarker = block.isSameKindOfList(as: self[index - 1]) && !usesSecondMarker
        result += (isInListItem && block.canFollowTextDirectly) ? "\n" : "\n\n"
      }
      result += block.renderMarkdown(usesSecondMarker: usesSecondMarker)
    }
    return result
  }
}

// MARK: - List rendering

extension Formatter.ListItem {
  /// The item with `marker` ahead of its first line and the lines after it indented to the
  /// marker's width, which is what keeps them in the item.
  fileprivate func renderMarkdown(marker: String) -> String {
    let content = blocks.renderMarkdown(isInListItem: true)

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
      case "\\", "`", "*", "[", "]", "~":
        result.append("\\")
      case "<":
        // Ahead of a letter or one of these, it would start HTML or an address in angle brackets.
        if let next = rest.first, next.isLetter || "/!?".contains(next) {
          result.append("\\")
        }
      case "&":
        if rest.startsCharacterReference {
          result.append("\\")
        }
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

  /// A line of a paragraph whose first characters would make it a heading, a quote, a list item
  /// or a divider, or turn the line above into a heading, with a backslash that keeps it text.
  fileprivate func escapingMarkdownBlockStart() -> String {
    if self.hasPrefix("#") || self.hasPrefix(">") {
      return "\\" + self
    }
    if self == "-" || self == "+" || self.hasPrefix("- ") || self.hasPrefix("+ ") {
      return "\\" + self
    }
    if self.contains(where: { $0 == "-" || $0 == "=" }),
      self.allSatisfy({ $0 == "-" || $0 == "=" || $0 == " " })
    {
      return "\\" + self
    }
    let digits = self.prefix(while: \.isNumber)
    let afterDigits = self.dropFirst(digits.count)
    if !digits.isEmpty,
      afterDigits == "." || afterDigits == ")" || afterDigits.hasPrefix(". ")
        || afterDigits.hasPrefix(") ")
    {
      return String(digits) + "\\" + afterDigits
    }
    return self
  }

  /// A heading's text with a backslash ahead of number signs at its end, which Markdown would
  /// otherwise read as an optional closing sequence and drop.
  fileprivate func escapingClosingNumberSigns() -> String {
    let numberSigns = self.reversed().prefix { $0 == "#" }
    guard !numberSigns.isEmpty else { return self }

    let start = self.dropLast(numberSigns.count)
    guard start.isEmpty || start.last == " " || start.last == "\t" else { return self }
    return String(start) + "\\" + String(numberSigns)
  }

  /// The code between backticks: more of them than the code has in a row, and a space on each
  /// side when the code starts or ends with a backtick or has a space at both ends.
  fileprivate func markdownCodeSpan() -> String {
    let fence = String(repeating: "`", count: longestBacktickRun() + 1)
    // Markdown takes one space off each end of code that has one at both ends.
    let hasSpacesAtBothEnds =
      self.hasPrefix(" ") && self.hasSuffix(" ") && !self.allSatisfy { $0 == " " }
    let needsPadding = self.hasPrefix("`") || self.hasSuffix("`") || hasSpacesAtBothEnds
    let padding = (needsPadding) ? " " : ""
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

extension Substring {
  /// Whether the text starts with the name or number of a character reference, like `copy;`
  /// or `#169;`, so an `&` ahead of it would be read as that character.
  fileprivate var startsCharacterReference: Bool {
    let name = self.prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "#") }
    return !name.isEmpty && self.dropFirst(name.count).first == ";"
  }
}

extension URL {
  /// The address for a link, in angle brackets when its parentheses don't pair up, since an
  /// unpaired `)` would end the link early.
  fileprivate var markdownLinkDestination: String {
    let address = absoluteString
    var depth = 0
    for character in address {
      if character == "(" {
        depth += 1
      } else if character == ")" {
        depth -= 1
        if depth < 0 { break }
      }
    }
    return (depth == 0) ? address : "<\(address)>"
  }
}
