import UIKit

/// Observes the keyboard frame and notifies its subscriber.
final class KeyboardFrameObserver {
    private let onKeyboardFrameUpdate: OnKeyboardFrameUpdate

    /// Provides the last known keyboard state.
    ///
    /// This will only be used for sending an initial event.
    ///
    private let keyboardStateProvider: KeyboardStateProviding

    /// Notifies the closure owner about any keyboard frame change.
    /// Note that the frame is based on the keyboard window coordinate.
    typealias OnKeyboardFrameUpdate = (_ keyboardFrame: CGRect) -> Void

    private let notificationCenter: NotificationCenter

    private var keyboardFrame: CGRect? {
        didSet {
            if let keyboardFrame = keyboardFrame, oldValue != keyboardFrame {
                onKeyboardFrameUpdate(keyboardFrame)
            }
        }
    }

    init(notificationCenter: NotificationCenter = NotificationCenter.default,
         keyboardStateProvider: KeyboardStateProviding = ServiceLocator.keyboardStateProvider,
         onKeyboardFrameUpdate: @escaping OnKeyboardFrameUpdate) {
        self.notificationCenter = notificationCenter
        self.keyboardStateProvider = keyboardStateProvider
        self.onKeyboardFrameUpdate = onKeyboardFrameUpdate
    }

    /// Start observing for keyboard notifications and notify subscribers when they arrive.
    ///
    /// - Parameter sendInitialEvent: If true, the subscriber will be immediately notified
    ///                               using the last known keyboard frame.
    func startObservingKeyboardFrame(sendInitialEvent: Bool = false) {
        notificationCenter.addObserver(self,
                                       selector: #selector(keyboardWillShow(_:)),
                                       name: UIResponder.keyboardWillShowNotification,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(keyboardWillHide(_:)),
                                       name: UIResponder.keyboardWillHideNotification,
                                       object: nil)

        if sendInitialEvent {
            let currentState = keyboardStateProvider.state
            // Always check the `isVisible` because `frameEnd` can still return a non-zero value.
            // See the `frameEnd` documentation why.
            keyboardFrame = currentState.isVisible ? currentState.frameEnd : .zero
        }
    }
}

private extension KeyboardFrameObserver {
    @objc func keyboardWillShow(_ notification: Foundation.Notification) {
        guard let keyboardFrame = keyboardRect(from: notification) else {
            return
        }
        self.keyboardFrame = keyboardFrame
    }

    @objc func keyboardWillHide(_ notification: Foundation.Notification) {
        self.keyboardFrame = .zero
    }
}

private extension KeyboardFrameObserver {
    /// Returns the Keyboard Rect from a Keyboard Notification.
    ///
    func keyboardRect(from note: Notification) -> CGRect? {
        let wrappedRect = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        return wrappedRect?.cgRectValue
    }
}
