import Cocoa
import SwiftUI

/// Controls the floating HUD overlay window.
final class HUDWindowController: @unchecked Sendable {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private let hudWidth: CGFloat = 240
    private let hudHeight: CGFloat = 46

    init() {
        DispatchQueue.main.async { [weak self] in
            self?.setupPanel()
        }
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: hudWidth, height: hudHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.isReleasedWhenClosed = false

        self.panel = panel
    }

    /// Shows or updates the HUD with current volume and mute state.
    func show(volume: Float, isMuted: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.panel == nil {
                self.setupPanel()
            }
            guard let panel = self.panel else { return }

            // Update content
            let hudView = VolumeHUDView(volume: volume, isMuted: isMuted)
            panel.contentView = NSHostingView(rootView: hudView)

            // Position at bottom center of current screen
            self.reposition(panel: panel)

            // Cancel any pending dismissal
            self.dismissWorkItem?.cancel()

            // Display panel
            panel.alphaValue = 1.0
            panel.orderFrontRegardless()

            // Auto-dismiss after 1.5 seconds
            let workItem = DispatchWorkItem { [weak panel] in
                guard let panel = panel else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().alphaValue = 0.0
                } completionHandler: {
                    if panel.alphaValue == 0.0 {
                        panel.orderOut(nil)
                    }
                }
            }

            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        }
    }

    private func reposition(panel: NSPanel) {
        // Find screen with cursor, or fallback to main screen
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

        guard let screen = targetScreen else { return }
        let visibleFrame = screen.visibleFrame

        let x = visibleFrame.midX - (hudWidth / 2.0)
        let y = visibleFrame.minY + 65.0 // Floats comfortably above dock

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
