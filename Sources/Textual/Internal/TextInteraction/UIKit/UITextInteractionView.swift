#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI
  import os

  // MARK: - Overview
  //
  // `UITextInteractionView` implements selection and link interaction on iOS-family platforms.
  //
  // The view sits in an overlay above one or more rendered `Text` fragments. It uses
  // `TextSelectionModel` to translate touch locations into URLs and selection ranges, and it
  // excludes `overflowRegions` from hit-testing so embedded scrollable regions can continue to
  // handle gestures. A selection that runs past a region copies and highlights all of it.
  // Selection UI is provided by `UITextInteraction` configured for non-editable content.

  final class UITextInteractionView: UIView {
    override var canBecomeFirstResponder: Bool {
      true
    }

    /// Clears the selection once another view takes focus, since Copy only uses the focused text.
    override func resignFirstResponder() -> Bool {
      guard super.resignFirstResponder() else {
        return false
      }
      model.selectedRange = nil
      return true
    }

    var model: TextSelectionModel
    var overflowRegions: [OverflowRegion] {
      didSet {
        updateOverflowRegionHighlights()
      }
    }
    var openURL: OpenURLAction

    /// The end of the selection that a drag moves away from, when the last change shows which one.
    var selectionAnchor: TextPosition?

    weak var inputDelegate: (any UITextInputDelegate)?

    let logger = Logger(category: .textInteraction)

    private(set) lazy var _tokenizer = UITextInputStringTokenizer(textInput: self)
    private let selectionInteraction: UITextInteraction
    private var overflowRegionHighlights: [UIView] = []

    init(
      model: TextSelectionModel,
      overflowRegions: [OverflowRegion],
      openURL: OpenURLAction
    ) {
      self.model = model
      self.overflowRegions = overflowRegions
      self.openURL = openURL
      self.selectionInteraction = UITextInteraction(for: .nonEditable)

      super.init(frame: .zero)
      self.backgroundColor = .clear

      setUp()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      for overflowRegion in overflowRegions {
        if overflowRegion.frame.contains(point) {
          return false
        }
      }
      return super.point(inside: point, with: event)
    }

    override func tintColorDidChange() {
      super.tintColorDidChange()
      updateOverflowRegionHighlights()
    }

    /// Highlights the overflow regions the selection runs past with plain views. UIKit draws the
    /// text highlight into one shape layer, and a region as tall as a long code block made that
    /// layer render at low resolution, shifting the highlight off the text.
    private func updateOverflowRegionHighlights() {
      let regions = model.selectedRange.map { model.overflowRegions(overflowRegions, in: $0) } ?? []

      while overflowRegionHighlights.count > regions.count {
        overflowRegionHighlights.removeLast().removeFromSuperview()
      }
      while overflowRegionHighlights.count < regions.count {
        let highlight = UIView()
        highlight.isUserInteractionEnabled = false
        insertSubview(highlight, at: 0)
        overflowRegionHighlights.append(highlight)
      }

      // The same color UIKit gives the text highlight
      let color = tintColor.withAlphaComponent(0.2)
      for (highlight, region) in zip(overflowRegionHighlights, regions) {
        highlight.frame = region.frame
        highlight.backgroundColor = color
      }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
      switch action {
      case #selector(copy(_:)), #selector(share(_:)):
        return !(model.selectedRange?.isCollapsed ?? true)
      default:
        return false
      }
    }

    override func copy(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange, including: overflowRegions)
      let formatter = Formatter(attributedText)

      UIPasteboard.general.setItems(formatter.pasteboardItems())
    }

    private func setUp() {
      model.selectionWillChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionWillChange(self)
      }
      model.selectionDidChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionDidChange(self)
        self.updateOverflowRegionHighlights()
      }

      let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      addGestureRecognizer(tapGesture)

      selectionInteraction.textInput = self
      selectionInteraction.delegate = self

      for gesture in selectionInteraction.gesturesForFailureRequirements {
        tapGesture.require(toFail: gesture)
      }

      addInteraction(selectionInteraction)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
      let location = gesture.location(in: self)
      guard let url = model.url(for: location) else {
        // On Mac Catalyst, the second click of a double-click reaches this handler after
        // `UITextInteraction` has selected the word, so clearing here would undo that selection.
        // A single click already clears the selection there.
        #if !targetEnvironment(macCatalyst)
          model.selectedRange = nil
        #endif
        return
      }
      openURL(url)
    }

    @objc private func share(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange, including: overflowRegions)
      let itemSource = TextActivityItemSource(attributedString: attributedText)

      let activityViewController = UIActivityViewController(
        activityItems: [itemSource],
        applicationActivities: nil
      )

      if let popover = activityViewController.popoverPresentationController {
        let rect =
          model.selectionRects(for: selectedRange)
          .last?.rect.integral ?? .zero
        popover.sourceView = self
        popover.sourceRect = rect
      }

      if let windowScene = window?.windowScene,
        let viewController = windowScene.windows.first?.rootViewController
      {
        viewController.present(activityViewController, animated: true)
      }
    }
  }

  extension UITextInteractionView: UITextInteractionDelegate {
    func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
      logger.debug("interactionShouldBegin(at: \(point.logDescription)) -> true")
      return true
    }

    func interactionWillBegin(_ interaction: UITextInteraction) {
      logger.debug("interactionWillBegin")
      _ = self.becomeFirstResponder()
    }

    func interactionDidEnd(_ interaction: UITextInteraction) {
      logger.debug("interactionDidEnd")
    }
  }

  extension Logger.Textual.Category {
    fileprivate static let textInteraction = Self(rawValue: "textInteraction")
  }
#endif
