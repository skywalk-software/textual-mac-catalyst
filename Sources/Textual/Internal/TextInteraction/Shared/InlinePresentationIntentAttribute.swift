#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  /// Keeps a run's inline styles through SwiftUI's rendering, which drops them, for Copy.
  struct InlinePresentationIntentAttribute: TextAttribute {
    var intent: InlinePresentationIntent
  }

  extension Text.Layout.Run {
    var inlinePresentationIntent: InlinePresentationIntent? {
      self[InlinePresentationIntentAttribute.self]?.intent
    }
  }
#endif
