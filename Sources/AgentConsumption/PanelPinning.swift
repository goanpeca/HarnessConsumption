import AppKit
import SwiftUI

/// Keeps a `MenuBarExtra` window's top edge just below the menu bar.
///
/// macOS positions the window once and then keeps its bottom edge fixed when the content resizes,
/// which leaves it hanging below the bar (shrinking) or tucked behind it (growing). Re-pinning the
/// top on every show and resize avoids both.
private struct PanelPinning: NSViewRepresentable {
    static let gap: CGFloat = 4

    func makeNSView(context: Context) -> PinView { PinView() }
    func updateNSView(_ view: PinView, context: Context) {}

    final class PinView: NSView {
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification,
                NSWindow.didChangeScreenNotification,
            ]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    // queue: .main, so this already runs on the main actor
                    MainActor.assumeIsolated { self?.pin() }
                }
            }
            DispatchQueue.main.async { [weak self] in self?.pin() }
        }

        private func pin() {
            guard let window, let screen = window.screen ?? NSScreen.main else { return }
            let top = screen.visibleFrame.maxY - PanelPinning.gap
            guard abs(window.frame.maxY - top) > 0.5 else { return }
            var frame = window.frame
            frame.origin.y = top - frame.height
            window.setFrame(frame, display: true)
        }
    }
}

extension View {
    /// Attach inside a `MenuBarExtra(.window)` view.
    func pinnedBelowMenuBar() -> some View { background(PanelPinning()) }
}
