import Cocoa
import SwiftUI

/// Controls the floating Brooklyn Nine-Nine Volume HUD overlay window.
@MainActor
public final class HUDWindowController {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private var viewModel: VolumeHUDViewModel?
    private var hostingView: NSHostingView<VolumeHUDView>?

    public let hudWidth: CGFloat = 680
    public let hudHeight: CGFloat = 136

    public init() {
        setupPanel()
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
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.isReleasedWhenClosed = false

        let currentVol = VolumeManager.shared.volume
        let currentMuted = VolumeManager.shared.isMuted
        let vm = VolumeHUDViewModel(volume: currentVol, isMuted: currentMuted)
        let hudView = VolumeHUDView(viewModel: vm)
        let host = NSHostingView(rootView: hudView)
        host.frame = NSRect(x: 0, y: 0, width: hudWidth, height: hudHeight)
        panel.contentView = host

        self.viewModel = vm
        self.hostingView = host
        self.panel = panel
    }

    private var dismissGeneration: Int = 0

    /// Shows or updates the HUD with current volume and mute state.
    public func show(volume: Float, isMuted: Bool) {
        if self.panel == nil || self.viewModel == nil {
            self.setupPanel()
        }
        guard let panel = self.panel, let viewModel = self.viewModel else { return }

        // Update state dynamically without recreating view hierarchy
        viewModel.update(volume: volume, isMuted: isMuted)

        // Reposition at bottom center of active display with cursor
        self.reposition(panel: panel)

        // Invalidate any in-flight dismissal generation
        self.dismissGeneration += 1
        let generation = self.dismissGeneration

        // Cancel any pending dismissal
        self.dismissWorkItem?.cancel()
        self.dismissWorkItem = nil

        // Cancel any in-flight fade animation and display panel immediately
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.0
        panel.animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()

        // Auto-dismiss after 1.8 seconds of inactivity
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self = self, let panel = panel, self.dismissGeneration == generation else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0.0
            } completionHandler: { [weak self, weak panel] in
                MainActor.assumeIsolated {
                    guard let self = self, let panel = panel, self.dismissGeneration == generation else { return }
                    panel.orderOut(nil)
                    panel.alphaValue = 1.0
                }
            }
        }

        self.dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    /// Immediately hides the HUD panel and cancels pending auto-dismiss.
    public func hide() {
        self.dismissGeneration += 1
        self.dismissWorkItem?.cancel()
        self.dismissWorkItem = nil
        panel?.orderOut(nil)
        panel?.alphaValue = 1.0
    }

    private func reposition(panel: NSPanel) {
        // Find screen with cursor, or fallback to main screen
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

        guard let screen = targetScreen else { return }
        let visibleFrame = screen.visibleFrame

        let x = round(visibleFrame.midX - (hudWidth / 2.0))
        let y = round(visibleFrame.minY + 65.0) // Floats comfortably above dock

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
