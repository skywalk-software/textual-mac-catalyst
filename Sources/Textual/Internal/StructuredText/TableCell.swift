import SwiftUI

extension StructuredText {
  struct TableCell: View {
    @Environment(\.tableCellStyle) private var tableCellStyle

    private let content: AttributedSubstring?
    private let identifier: TableCell.Identifier

    /// Creates a cell; `nil` content makes an empty cell that still takes its place in the row.
    init(_ content: AttributedSubstring?, row: Int, column: Int) {
      self.content = content
      self.identifier = .init(row: row, column: column)
    }

    var body: some View {
      let configuration = TableCellStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel,
        row: identifier.row,
        column: identifier.column
      )
      let resolvedStyle =
        tableCellStyle
        .resolve(configuration: configuration)
        .anchorPreference(key: BoundsKey.self, value: .bounds) { anchor in
          [identifier: anchor]
        }

      AnyView(resolvedStyle)
    }

    @ViewBuilder
    private var label: some View {
      if let content {
        WithInlineStyle(AttributedString(content)) {
          TextFragment($0)
        }
        // A cell is narrower than the whole text, so its attachments are measured against the cell.
        .coordinateSpace(.textContainer)
      } else {
        Color.clear
          .frame(width: 0, height: 0)
      }
    }

    private var indentationLevel: Int {
      content?.presentationIntent?.indentationLevel ?? 0
    }
  }
}

extension StructuredText.TableCell {
  struct Identifier: Hashable {
    let row: Int
    let column: Int
  }

  struct BoundsKey: PreferenceKey {
    static let defaultValue: [Identifier: Anchor<CGRect>] = [:]

    static func reduce(
      value: inout [Identifier: Anchor<CGRect>],
      nextValue: () -> [Identifier: Anchor<CGRect>]
    ) {
      value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
  }
}

extension StructuredText.TableCell {
  struct Spacing: Sendable, Hashable {
    let horizontal: CGFloat?
    let vertical: CGFloat?

    init(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) {
      self.horizontal = horizontal
      self.vertical = vertical
    }
  }

  struct SpacingKey: PreferenceKey {
    static let defaultValue = Spacing()

    static func reduce(value: inout Spacing, nextValue: () -> Spacing) {
      value = nextValue()
    }
  }
}
