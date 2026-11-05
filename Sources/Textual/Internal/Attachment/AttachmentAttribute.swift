import SwiftUI

// MARK: - Overview
//
// Attachments are stored in attributed content as a `Textual.Attachment` attribute, but SwiftUI
// `Text` can’t embed arbitrary views. The rendering pipeline converts these runs into placeholder
// `Text` segments and uses an overlay to draw the real views at the resolved layout positions.
//
// `AttachmentAttribute` is attached to the placeholder runs during `Text` construction. It carries:
// - the original attachment value (type-erased as `AnyAttachment`)
// - the size the attachment was measured at, which the overlay lays the attachment out at
// - the run's `PresentationIntent` (used by formatters and higher-level rendering)
//
// `Text.Layout.Run` exposes lightweight accessors so overlay code can discover attachments without
// reaching back into the original attributed string.

struct AttachmentAttribute: TextAttribute {
  var attachment: AnyAttachment
  var size: CGSize
  var presentationIntent: PresentationIntent?

  init(_ attachment: AnyAttachment, size: CGSize, presentationIntent: PresentationIntent?) {
    self.attachment = attachment
    self.size = size
    self.presentationIntent = presentationIntent
  }
}

extension Text.Layout.Run {
  var attachment: AnyAttachment? {
    self[AttachmentAttribute.self]?.attachment
  }

  var attachmentSize: CGSize? {
    self[AttachmentAttribute.self]?.size
  }

  var attachmentPresentationIntent: PresentationIntent? {
    self[AttachmentAttribute.self]?.presentationIntent
  }
}
