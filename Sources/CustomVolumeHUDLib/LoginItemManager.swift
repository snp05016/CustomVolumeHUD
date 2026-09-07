import Foundation
import ServiceManagement
import AppKit

/// Manages registration and removal of CustomVolumeHUD as a macOS login item.
public final class LoginItemManager: @unchecked Sendable {
    public static let shared = LoginItemManager()

    public static let appName = "CustomVolumeHUD"
    public static let defaultAppBundlePath = "/Applications/CustomVolumeHUD.app"

    public init() {}

    /// Resolves the absolute path to the app bundle to be launched at login.
    public func resolvedAppBundlePath(overridePath: String? = nil) -> String {
        if let overridePath, !overridePath.isEmpty {
            return overridePath
        }

        let mainBundlePath = Bundle.main.bundlePath
        if mainBundlePath.hasSuffix(".app") &&
           (mainBundlePath.contains("CustomVolumeHUD") || Bundle.main.bundleIdentifier == "com.user.CustomVolumeHUD") &&
           FileManager.default.fileExists(atPath: mainBundlePath) {
            return mainBundlePath
        }

        if FileManager.default.fileExists(atPath: Self.defaultAppBundlePath) {
            return Self.defaultAppBundlePath
        }

        // Check if current executable is inside an .app bundle
        let executablePath = CommandLine.arguments.first ?? ""
        if let appRange = executablePath.range(of: ".app") {
            let appPath = String(executablePath[..<appRange.upperBound])
            if appPath.contains("CustomVolumeHUD") && FileManager.default.fileExists(atPath: appPath) {
                return appPath
            }
        }

        return Self.defaultAppBundlePath
    }

    /// Checks if launch at login is currently enabled.
    public var isEnabled: Bool {
        // Modern SMAppService check (macOS 13+)
        if #available(macOS 13.0, *),
           let bundleId = Bundle.main.bundleIdentifier,
           bundleId == "com.user.CustomVolumeHUD" {
            let status = SMAppService.mainApp.status
            if status == .enabled {
                return true
            }
        }

        // System Events check
        return isSystemEventsLoginItemRegistered(name: Self.appName)
    }

    /// Enables start on login.
    @discardableResult
    public func enable(appPath: String? = nil) -> Bool {
        let targetPath = resolvedAppBundlePath(overridePath: appPath)

        // Try modern SMAppService first if running from the registered bundle
        if #available(macOS 13.0, *),
           let bundleId = Bundle.main.bundleIdentifier,
           bundleId == "com.user.CustomVolumeHUD" {
            do {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
                if SMAppService.mainApp.status == .enabled {
                    return true
                }
            } catch {
                // Fall back to System Events
            }
        }

        // Fallback: Register in System Events Login Items
        return registerSystemEventsLoginItem(path: targetPath, name: Self.appName)
    }

    /// Disables start on login.
    @discardableResult
    public func disable() -> Bool {
        var unregistered = false

        if #available(macOS 13.0, *),
           let bundleId = Bundle.main.bundleIdentifier,
           bundleId == "com.user.CustomVolumeHUD" {
            do {
                try SMAppService.mainApp.unregister()
                unregistered = true
            } catch {
                // Ignore and proceed to System Events removal
            }
        }

        if unregisterSystemEventsLoginItem(name: Self.appName) {
            unregistered = true
        }

        return unregistered
    }

    // MARK: - System Events AppleScript Support

    public func isSystemEventsLoginItemRegistered(name: String = appName) -> Bool {
        let script = """
        tell application "System Events"
            return exists (login item "\(name)")
        end tell
        """
        return runAppleScriptBoolean(script)
    }

    public func registerSystemEventsLoginItem(path: String, name: String = appName) -> Bool {
        let script = """
        tell application "System Events"
            if exists (login item "\(name)") then
                delete (login item "\(name)")
            end if
            make login item at end with properties {path:"\(path)", hidden:false, name:"\(name)"}
            return exists (login item "\(name)")
        end tell
        """
        return runAppleScriptBoolean(script)
    }

    public func unregisterSystemEventsLoginItem(name: String = appName) -> Bool {
        let script = """
        tell application "System Events"
            if exists (login item "\(name)") then
                delete (login item "\(name)")
            end if
            return not (exists (login item "\(name)"))
        end tell
        """
        return runAppleScriptBoolean(script)
    }

    private func runAppleScriptBoolean(_ source: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return false }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output.lowercased() == "true"
            }
        } catch {
            return false
        }
        return false
    }
}
