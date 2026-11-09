import SwiftUI

// MARK: - Overview
//
// OverflowRegionKey collects scrollable overflow regions (like code blocks) and propagates them via
// preferences to selection overlays. Each region carries its frame in the text container and the
// text layouts inside it.
//
// Text selection uses the frames to exclude scrollable regions from hit-testing so embedded
// ScrollViews can receive touch events while the parent selection interaction ignores them. A
// region keeps its own local selection, so a parent selection that runs past it highlights and
// copies the whole region instead.

struct OverflowRegion: Equatable {
  var frame: CGRect
  var layouts: [Text.Layout]
}

struct OverflowRegionKey: PreferenceKey {
  static var defaultValue: [OverflowRegion] { [] }

  static func reduce(value: inout [OverflowRegion], nextValue: () -> [OverflowRegion]) {
    value.append(contentsOf: nextValue())
  }
}

// Carries an overflow region's text layouts from its scrolling content up to where its frame is read
struct OverflowTextLayoutKey: PreferenceKey {
  static var defaultValue: [Text.Layout] { [] }

  static func reduce(value: inout [Text.Layout], nextValue: () -> [Text.Layout]) {
    value.append(contentsOf: nextValue())
  }
}
