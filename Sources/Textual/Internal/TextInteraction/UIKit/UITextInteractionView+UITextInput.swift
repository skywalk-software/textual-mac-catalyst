#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI

  extension UITextInteractionView: UITextInput {
    var hasText: Bool {
      model.hasText
    }

    func insertText(_: String) {
      // Do nothing
    }

    func deleteBackward() {
      // Do nothing
    }

    func text(in range: UITextRange) -> String? {
      guard let range = validRange(range) else { return nil }
      return model.text(in: range)
    }

    func replace(_ range: UITextRange, withText text: String) {
      // Do nothing
    }

    var selectedTextRange: UITextRange? {
      get { model.selectedRange.map(TextRangeBox.init) }
      set {
        let range = validRange(newValue)
        selectionAnchor = range.flatMap { anchor(of: $0, after: model.selectedRange) }
        model.selectedRange = range
        logger.debug("selectedTextRange = \(newValue)")
      }
    }

    /// The end of `range` that stayed where it was in `previousRange`, including when a drag
    /// crosses over it. Nil for a selection that doesn't continue the previous one.
    private func anchor(of range: TextRange, after previousRange: TextRange?) -> TextPosition? {
      guard let previousRange else { return nil }
      guard range != previousRange else { return selectionAnchor }

      if range.start == previousRange.start || range.start == previousRange.end {
        return range.start
      }
      if range.end == previousRange.end || range.end == previousRange.start {
        return range.end
      }
      return nil
    }

    var markedTextRange: UITextRange? {
      nil
    }

    var markedTextStyle: [NSAttributedString.Key: Any]? {
      get { nil }
      set {}
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
      // Do nothing
    }

    func unmarkText() {
      // Do nothing
    }

    var beginningOfDocument: UITextPosition {
      TextPositionBox(model.startPosition)
    }

    var endOfDocument: UITextPosition {
      TextPositionBox(model.endPosition)
    }

    func textRange(
      from fromPosition: UITextPosition,
      to toPosition: UITextPosition
    ) -> UITextRange? {
      guard
        let from = fromPosition as? TextPositionBox,
        let to = toPosition as? TextPositionBox
      else {
        return nil
      }
      return TextRangeBox(from: from, to: to)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
      guard let position = validPosition(position) else { return nil }
      return model.position(
        from: position,
        offset: offset
      ).map(TextPositionBox.init)
    }

    func position(
      from position: UITextPosition,
      in direction: UITextLayoutDirection,
      offset: Int
    ) -> UITextPosition? {
      logger.error("position(from:in:offset:) is not implemented")
      return nil
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
      guard
        let lhs = position as? TextPositionBox, let rhs = other as? TextPositionBox,
        lhs.wrappedValue != rhs.wrappedValue
      else {
        return .orderedSame
      }
      return lhs.wrappedValue < rhs.wrappedValue ? .orderedAscending : .orderedDescending
    }

    func offset(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> Int {
      guard
        let from = validPosition(fromPosition),
        let to = validPosition(toPosition)
      else { return 0 }
      return model.offset(from: from, to: to)
    }

    var tokenizer: any UITextInputTokenizer {
      self
    }

    func position(
      within range: UITextRange,
      farthestIn direction: UITextLayoutDirection
    ) -> UITextPosition? {
      logger.error("position(within:farthestIn:) is not implemented")
      return nil
    }

    func characterRange(
      byExtending position: UITextPosition,
      in direction: UITextLayoutDirection
    ) -> UITextRange? {
      logger.error("characterRange(byExtending:in:) is not implemented")
      return nil
    }

    func baseWritingDirection(
      for position: UITextPosition,
      in direction: UITextStorageDirection
    ) -> NSWritingDirection {
      // Not applicable for non-editable interaction mode?
      return .natural
    }

    func setBaseWritingDirection(_: NSWritingDirection, for _: UITextRange) {
      // Do nothing
    }

    func firstRect(for range: UITextRange) -> CGRect {
      guard let range = validRange(range) else { return .zero }
      return model.firstRect(for: range)
    }

    func caretRect(for position: UITextPosition) -> CGRect {
      guard let position = validPosition(position) else { return .zero }
      return model.caretRect(for: position)
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
      guard let range = validRange(range) else { return [] }
      return model.selectionRects(for: range)
        .map(TextSelectionRectBox.init)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
      (positionPastOverflowRegion(at: point) ?? model.closestPosition(to: point))
        .map(TextPositionBox.init)
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
      guard let range = validRange(range) else { return nil }
      if let position = positionPastOverflowRegion(at: point) {
        let clamped = min(max(position, range.start), range.end)
        return TextPositionBox(clamped)
      }
      return model.closestPosition(
        to: point,
        within: range
      ).map(TextPositionBox.init)
    }

    /// The position just past the overflow region under `point`, on the far side from the
    /// selection's anchor, so dragging into a region selects all of it. Without a known anchor,
    /// the side nearer `point`. Nil when `point` isn't over a region.
    private func positionPastOverflowRegion(at point: CGPoint) -> TextPosition? {
      guard let region = overflowRegions.first(where: { $0.frame.contains(point) }) else {
        return nil
      }

      let before = model.position(before: region)
      let after = model.position(after: region)

      if let selectionAnchor {
        return (selectionAnchor <= before) ? after : before
      }
      return (point.y > region.frame.midY) ? after : before
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
      model.characterRange(at: point).map(TextRangeBox.init)
    }

    var textInputView: UIView {
      self
    }

    var isEditable: Bool {
      false
    }

    func attributedText(in range: UITextRange) -> NSAttributedString {
      guard let range = validRange(range) else { return .init() }
      return model.attributedText(in: range)
    }
  }
#endif
