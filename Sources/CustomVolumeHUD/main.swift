import Cocoa
import ApplicationServices
import CustomVolumeHUDLib

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudController: HUDWindowController!
    private var mediaKeyInterceptor: MediaKeyInterceptor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        hudController = HUDWindowController()
        mediaKeyInterceptor = MediaKeyInterceptor()

        setupVolumeHandlers()
        requestAccessibilityAndStart()

        print("✨ CustomVolumeHUD is running.")
        print("💡 Use your volume keys or Control Center to see the custom HUD.")
    }

    private func setupVolumeHandlers() {
        // Intercepted media keys handler (suppressed default HUD)
        mediaKeyInterceptor.onVolumeAdjusted = { [weak self] volume, isMuted, action, outputDevice in
            self?.hudController.show(
                volume: volume,
                isMuted: isMuted,
                inputAction: action,
                bluetoothOutputDevice: VolumeManager.shared.bluetoothOutputDevice,
                outputDevice: outputDevice
            )
        }

        // CoreAudio system volume listener (catches Control Center / slider adjustments)
        VolumeManager.shared.onVolumeChanged = { [weak self] volume, isMuted in
            self?.hudController.show(
                volume: volume,
                isMuted: isMuted,
                inputAction: .externalChange,
                bluetoothOutputDevice: VolumeManager.shared.bluetoothOutputDevice,
                outputDevice: nil
            )
        }
    }

    private func requestAccessibilityAndStart() {
        // Prompt system for accessibility permissions if not already granted
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [promptKey: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if isTrusted && mediaKeyInterceptor.start() {
            print("🔒 Media key interception active (Native HUD suppressed).")
        } else {
            if !isTrusted {
                print("⚠️ Accessibility permission not yet granted.")
                print("👉 Please grant Accessibility permission in System Settings to suppress the default macOS HUD.")
                print("ℹ️ Falling back to CoreAudio listener mode.")
            } else {
                print("⚠️ Could not start event tap initially; will retry periodically.")
            }

            // Poll periodically until event tap is successfully started (.common modes to survive menu tracking)
            let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] timer in
                MainActor.assumeIsolated {
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }
                    if AXIsProcessTrusted() && self.mediaKeyInterceptor.start() {
                        timer.invalidate()
                        print("✅ Accessibility permission active! Native HUD suppression activated.")
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
    }

}

@main
struct CustomVolumeHUDApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
