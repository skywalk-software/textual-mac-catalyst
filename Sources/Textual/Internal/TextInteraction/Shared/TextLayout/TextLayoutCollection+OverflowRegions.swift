#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  // MARK: - Overview
  //
  // Overflow regions (like scrolling code blocks) keep their own local selection, so their text
  // isn't part of this collection. A selection that runs past a region takes the whole region:
  // copying includes its text in reading order, and the highlight covers its frame.
  //
  // A region sits in the gap before the first layout below it. A selection runs past that gap when
  // it starts in an earlier layout and ends in that layout or a later one. A gap above the first
  // layout or below the last one counts when the selection reaches the start or end of the text.

  extension TextLayoutCollection {
    /// The regions `range` runs past, in the order they appear.
    func overflowRegions(_ regions: [OverflowRegion], in range: TextRange) -> [OverflowRegion] {
      guard !range.isCollapsed else { return [] }
      return regions.filter { self.range(range, runsPastGap: gap(before: $0)) }
        .sorted { $0.frame.minY < $1.frame.minY }
    }

    /// The text in `range`, with the full text of each region it runs past, in reading order.
    func attributedText(
      in range: TextRange,
      including regions: [OverflowRegion]
    ) -> NSAttributedString {
      let selectedRegions = overflowRegions(regions, in: range)
      guard !selectedRegions.isEmpty else {
        return attributedText(in: range)
      }

      let attributedText = NSMutableAttributedString()
      let start = range.start.indexPath.layout
      let end = range.end.indexPath.layout

      for layout in start...end {
        for region in selectedRegions where gap(before: region) == layout {
          attributedText.append(region.attributedText)
        }

        let layoutStart = TextPosition(indexPath: .init(layout: layout), affinity: .downstream)
        guard let layoutRange = blockRange(for: layoutStart) else { continue }

        attributedText.append(
          self.attributedText(
            in: TextRange(
              start: (layout == start) ? range.start : layoutRange.start,
              end: (layout == end) ? range.end : layoutRange.end
            )
          )
        )
      }

      for region in selectedRegions where gap(before: region) > end {
        attributedText.append(region.attributedText)
      }

      return attributedText
    }

    /// The index of the first layout below `region`, or the layout count when none is.
    private func gap(before region: OverflowRegion) -> Int {
      layouts.firstIndex { $0.frame.midY > region.frame.midY } ?? layouts.count
    }

    private func range(_ range: TextRange, runsPastGap gap: Int) -> Bool {
      let startsAbove = range.start.indexPath.layout < gap || range.start == startPosition
      let endsBelow = range.end.indexPath.layout >= gap || range.end == endPosition
      return startsAbove && endsBelow
    }
  }

  extension OverflowRegion {
    var attributedText: NSAttributedString {
      let attributedText = NSMutableAttributedString()
      for layout in layouts where layout.isTextFragment {
        attributedText.append(LiveTextLayout(base: layout, origin: .zero).attributedString)
      }
      return attributedText
    }
  }
#endif
