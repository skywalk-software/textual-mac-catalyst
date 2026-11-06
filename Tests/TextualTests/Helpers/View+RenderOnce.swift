#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SnapshotTesting
  import SwiftUI

  @testable import Textual

  extension View {
    /// Renders the view once, the way snapshot tests do, and returns what `content` makes from its
    /// text layout collection.
    @MainActor
    func renderOnce<Value>(
      capturing content: @escaping (any TextLayoutCollection) -> Value
    ) async -> Value? {
      var captured: Value?
      let capturingView = overlayTextLayoutCollection { layoutCollection in
        captured = content(layoutCollection)
        return Color.clear
      }

      let image = Snapshotting<AnyView, UIImage>
        .image(layout: .device(config: .iPhoneSe))
        .snapshot(AnyView(capturingView))
      await withCheckedContinuation { continuation in
        image.run { _ in continuation.resume() }
      }

      return captured
    }
  }
#endif
