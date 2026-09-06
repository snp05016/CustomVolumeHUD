# CustomVolumeHUD (macOS) - Brooklyn Nine-Nine Edition 🚨

A custom pixel-art macOS Volume Heads-Up Display (HUD) themed around **Brooklyn Nine-Nine**, built natively with **Swift**, **AppKit**, and **SwiftUI**.

![70% Volume HUD](hud_preview_70.png)

---

## The Concept

- **Jake Peralta** (left) excitedly rapid-fires:
  ```
  COOL COOL COOL COOL COOL COOL COOL COOL COOL COOL
  ```
  where each active `COOL` represents 10% volume.
- **Captain Raymond Holt** (right) stands motionless and unimpressed as Jake gets progressively more excited.
- **Dynamic Directional Flow**: Increasing volume reveals words sequentially from Jake toward Holt with micro-delays and pixel bounces. Decreasing volume rapidly dissolves words right-to-left.
- **Special States & Reactions**:
  - **Mute**: All COOLs vanish immediately. After 300 ms, Holt displays a subtle *"Silence."* or *"Finally."* reaction.
  - **100% Volume**: Jake celebrates and Holt occasionally reacts with a raised eyebrow or *"Peralta."* speech bubble. Rare Easter eggs (*"NO DOUBT!"*, *"BINGPOT!"*) can trigger.

---

## Features

- 🎛️ **Native HUD Suppression**: Uses `CGEvent.tapCreate` to intercept volume keys (`F11`, `F12`, `Mute`) and suppress Apple's default bezel.
- 🔊 **CoreAudio Hardware Sync**: Authoritative system output volume synchronization with live device change listeners.
- 👾 **100% Nearest-Neighbor Pixel Art**: Custom `PixelArtSpriteView` ensures sprites remain sharp with zero bilinear blur on Retina displays.
- 📟 **Custom 5×7 Bitmap Font**: Built-in retro police computer typography engine (`PixelFont.swift`).
- ⚡ **Zero-Latency Catch-up**: Rapid keypresses collapse the animation queue (< 140 ms) so the HUD never lags behind actual volume changes.
- 🪟 **Floating & Non-Activating**: Runs as an `NSPanel` at `.statusBar` level across all spaces (including full-screen apps and games) with click-through enabled.
- 🧼 **Accessory Agent (No Dock Icon)**: Operates silently in the background with a menu bar status item.

---

## Quick Start

### 1. Run in Development Mode
Build and run directly using Swift Package Manager:

```bash
swift run
```

### 2. Build as a Standalone macOS App (`.app`)
Compile in Release mode and package into a signed `.app` bundle:

```bash
./scripts/build_app.sh
open CustomVolumeHUD.app
```

---

## Permissions (Accessibility)

To suppress the default macOS volume bezel:
1. Launch the application.
2. When prompted, open **System Settings > Privacy & Security > Accessibility**.
3. Enable the toggle for **CustomVolumeHUD** (or your terminal emulator if running via `swift run`).

---

## Testing

Run the automated test suite (26 unit and snapshot tests):

```bash
swift test
```

---

## Project Structure

```
CustomVolumeHUD/
├── Package.swift
├── scripts/
│   └── build_app.sh                  # Release bundler and code-signer
├── Sources/
│   ├── CustomVolumeHUD/              # Executable target entry point
│   │   └── main.swift
│   └── CustomVolumeHUDLib/           # Core library
│       ├── HUDWindowController.swift # Floating NSPanel controller
│       ├── MediaKeyInterceptor.swift # CGEventTap volume key interceptor
│       ├── PixelArtImageView.swift   # Nearest-neighbor pixel sprite renderer
│       ├── PixelFont.swift           # 5x7 bitmap retro font engine
│       ├── VolumeHUDView.swift       # SwiftUI terminal HUD view
│       ├── VolumeHUDViewModel.swift  # Interruptible animation state coordinator
│       ├── VolumeManager.swift       # CoreAudio volume driver & listener
│       └── Resources/                # Pixel art sprites (Jake, Holt)
└── Tests/
    └── CustomVolumeHUDTests/         # 26 automated unit & snapshot tests
```
