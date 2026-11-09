#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
  import SwiftUI

  // MARK: - Overview
  //
  // `AppKitTextInteractionOverlay` bridges the shared `TextSelectionModel` into an `NSView`.
  //
  // The overlay reads overflow regions for hit-testing. This allows embedded scrollable regions (like
  // code blocks) to receive touch events while the parent handles text selection. The view also
  // manages selection gestures, keyboard-driven updates, and context menus while SwiftUI renders
  // the text.

  struct AppKitTextInteractionOverlay: NSViewRepresentable {
    private let model: TextSelectionModel
    private let overflowRegions: [OverflowRegion]

    init(model: TextSelectionModel, overflowRegions: [OverflowRegion]) {
      self.model = model
      self.overflowRegions = overflowRegions
    }

    func makeNSView(context: Context) -> NSTextInteractionView {
      NSTextInteractionView(
        model: model,
        overflowRegions: overflowRegions,
        openURL: context.environment.openURL
      )
    }

    func updateNSView(_ nsView: NSTextInteractionView, context: Context) {
      nsView.model = model
      nsView.overflowRegions = overflowRegions
      nsView.openURL = context.environment.openURL
    }
  }
#endif
