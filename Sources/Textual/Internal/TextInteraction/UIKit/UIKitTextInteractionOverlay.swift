#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI

  // MARK: - Overview
  //
  // `UIKitTextInteractionOverlay` bridges the shared `TextSelectionModel` into a `UIView`.
  //
  // The overlay reads overflow regions for hit-testing. This allows embedded scrollable regions (like
  // code blocks) to receive touch events while the parent handles text selection. The view hosts
  // a `UITextInteraction` configured for selection and implements the `UITextInput` surface that
  // UIKit uses for selection behavior.

  struct UIKitTextInteractionOverlay: UIViewRepresentable {
    private let model: TextSelectionModel
    private let overflowRegions: [OverflowRegion]

    init(model: TextSelectionModel, overflowRegions: [OverflowRegion]) {
      self.model = model
      self.overflowRegions = overflowRegions
    }

    func makeUIView(context: Context) -> UITextInteractionView {
      UITextInteractionView(
        model: model,
        overflowRegions: overflowRegions,
        openURL: context.environment.openURL
      )
    }

    func updateUIView(_ uiView: UITextInteractionView, context: Context) {
      uiView.model = model
      uiView.overflowRegions = overflowRegions
      uiView.openURL = context.environment.openURL
    }
  }
#endif
