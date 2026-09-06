# CustomVolumeHUD (macOS)

A lightweight, customizable macOS volume Heads-Up Display (HUD) written in **Swift** and **SwiftUI**.

It intercepts system media keys to **suppress the default macOS volume bezel**, queries/updates hardware volume via **CoreAudio**, and renders a sleek, floating glassmorphic overlay.

---

## Features

- 🎛️ **Native HUD Suppression**: Uses `CGEvent.tapCreate` to intercept volume keys (`F11`, `F12`, `Mute`) and suppress Apple's default bezel.
- 🔊 **CoreAudio Hardware Sync**: Adjusts virtual main volume and responds to changes from Control Center, Touch Bar, or external audio devices.
- 🎨 **Modern Glassmorphic UI**: SwiftUI pill view with `.ultraThinMaterial`, SF Symbols (`speaker.wave.3.fill`, `speaker.slash.fill`), smooth spring animations, and exact percentage readouts.
- 🎚️ **Fine-Tuning Support**: Supports <kbd>⇧ Shift</kbd> + <kbd>⌥ Option</kbd> + Volume keys for fine-grained 1/4 step increments (1/64th step).
- 🪟 **Floating & Non-Activating**: Runs as an `NSPanel` that stays on top of all windows (including full-screen apps and multiple spaces) without stealing keyboard focus or causing clicks to miss.
- 🧼 **Accessory Agent (No Dock Icon)**: Lives silently in the menu bar with options to test the HUD or quit.

---

## Architecture

```
Hardware Volume Keys (F11 / F12 / Mute)
                 │
                 ▼
┌─────────────────────────────────┐
│ MediaKeyInterceptor             │
│  - CGEvent.tapCreate            │ ──(Drops event: Suppresses Default HUD)
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ VolumeManager (CoreAudio)       │ ◄── (Also listens to Control Center)
│  - AudioObjectSetPropertyData   │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ HUDWindowController (NSPanel)   │
│  - Floating, non-activating     │
│  - Auto-dismiss timer (1.5s)    │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ VolumeHUDView (SwiftUI)         │
│  - Glassmorphic Capsule         │
│  - Spring-animated progress bar │
└─────────────────────────────────┘
```

---

## Quick Start

### 1. Run in Development Mode
You can build and run the app directly from your terminal using the Swift Package Manager:

```bash
swift run
```

### 2. Build as a Standalone Application (`.app`)
Run the provided build script to compile in Release mode and create a self-contained `.app` bundle:

```bash
./scripts/build_app.sh
```

This generates `CustomVolumeHUD.app`. You can launch it with:
```bash
open CustomVolumeHUD.app
```

---

## Permissions (Accessibility)

To suppress the default macOS volume bezel, macOS requires **Accessibility Permissions**:
1. When you first run the app, macOS will prompt you to grant Accessibility access.
2. Go to **System Settings > Privacy & Security > Accessibility**.
3. Toggle the switch ON for **CustomVolumeHUD** (or your terminal emulator if running with `swift run`).

> **Note:** If permissions are not granted, the app automatically falls back to **CoreAudio listener mode**. The custom HUD will still display, but the default macOS bezel will appear alongside it until permission is granted.

---

## Customizing the HUD

- **Position**: Modify `reposition(panel:)` in `Sources/CustomVolumeHUD/HUDWindowController.swift` to place the HUD under the MacBook notch, in the top right corner, or centered at the bottom.
- **Visuals & Colors**: Edit `Sources/CustomVolumeHUD/VolumeHUDView.swift` to change capsule width, corner radius, gradients, or typography.
- **Dismiss Duration**: Adjust the timeout in `HUDWindowController.swift` (default: 1.5 seconds).

---

## Project Structure

```
CustomVolumeHUD/
├── Package.swift                    # SPM manifest
├── scripts/
│   └── build_app.sh                 # App bundler and code sign script
├── Sources/
│   └── CustomVolumeHUD/
│       ├── main.swift               # App entry point & Status Item
│       ├── VolumeManager.swift       # CoreAudio volume read/write & listener
│       ├── MediaKeyInterceptor.swift # Low-level CGEventTap key interceptor
│       ├── HUDWindowController.swift # Floating NSPanel controller
│       └── VolumeHUDView.swift      # SwiftUI HUD view
├── README.md
└── .gitignore
```
