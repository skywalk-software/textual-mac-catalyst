#if TEXTUAL_ENABLE_TEXT_SELECTION && os(iOS) && !targetEnvironment(macCatalyst)
  import SwiftUI
  import Testing

  @testable import Textual

  // APP-1361: a text kept its selection after another text or a text field took focus, so several
  // texts looked selected while Copy used only the focused one.
  @MainActor
  struct UITextInteractionViewTests {
    @Test
    func anotherTextTakingFocusClearsTheSelection() throws {
      // given
      let window = makeWindow()
      defer { window.isHidden = true }
      let (firstView, firstModel) = try makeSelectedView(in: window)
      let (secondView, _) = try makeSelectedView(in: window)
      #expect(firstView.becomeFirstResponder())

      // when
      let didFocus = secondView.becomeFirstResponder()

      // then
      #expect(didFocus)
      #expect(firstModel.selectedRange == nil)
    }

    @Test
    func textFieldTakingFocusClearsTheSelection() throws {
      // given
      let window = makeWindow()
      defer { window.isHidden = true }
      let (view, model) = try makeSelectedView(in: window)
      let textField = UITextField()
      window.addSubview(textField)
      #expect(view.becomeFirstResponder())

      // when
      let didFocus = textField.becomeFirstResponder()

      // then
      #expect(didFocus)
      #expect(model.selectedRange == nil)
    }

    private func makeWindow() -> UIWindow {
      let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
      window.makeKeyAndVisible()
      return window
    }

    /// Adds a text view to `window` with all of its text selected.
    private func makeSelectedView(
      in window: UIWindow
    ) throws -> (UITextInteractionView, TextSelectionModel) {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      model.selectedRange = TextRange(start: model.startPosition, end: model.endPosition)
      let view = UITextInteractionView(
        model: model,
        overflowRegions: [],
        openURL: OpenURLAction { _ in .discarded }
      )
      window.addSubview(view)
      return (view, model)
    }
  }
#endif
