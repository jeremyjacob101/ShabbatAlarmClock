import SwiftUI
import UIKit

struct KeyboardDismissTapInstaller: UIViewRepresentable {
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap

        if uiView.window == nil {
            DispatchQueue.main.async {
                context.coordinator.installIfNeeded(from: uiView)
            }
        } else {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        private weak var installedView: UIView?
        private lazy var tapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        func installIfNeeded(from uiView: UIView) {
            guard let targetView = uiView.window else { return }
            guard installedView !== targetView else { return }

            uninstall()
            targetView.addGestureRecognizer(tapRecognizer)
            installedView = targetView
        }

        func uninstall() {
            installedView?.removeGestureRecognizer(tapRecognizer)
            installedView = nil
        }

        @objc private func handleTap() {
            onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let touchedView = touch.view else { return true }
            return !isTextInputView(touchedView)
        }

        private func isTextInputView(_ view: UIView) -> Bool {
            var currentView: UIView? = view

            while let unwrappedView = currentView {
                if unwrappedView is UITextField || unwrappedView is UITextView {
                    return true
                }

                currentView = unwrappedView.superview
            }

            return false
        }
    }
}
