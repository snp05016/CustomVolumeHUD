# Original User Request

## 2026-09-06T04:23:38Z

This is a single self-contained feature build; keep it small and focused. Build a custom Brooklyn Nine-Nine themed macOS volume HUD featuring pixel-art Jake Peralta and Captain Holt with dynamic "COOL" volume steps.

Working directory: `/Users/saumya/CustomVolumeHUD`
Integrity mode: development

## Assets Provided
- Jake Peralta sprite: `/Users/saumya/.gemini/antigravity/brain/8c0f5738-1379-47df-a409-a56f8f4ab02e/.user_uploaded/media_1788668373184.png`
- Captain Raymond Holt sprite: `/Users/saumya/.gemini/antigravity/brain/8c0f5738-1379-47df-a409-a56f8f4ab02e/.user_uploaded/media_1788668443556.png`

## Requirements

### R1. Pixel Art Sprite Processing & Crisp Rendering
Process the provided Jake (white background) and Holt (black background) sprites to extract clean transparent PNGs, cropped to bounds, scaled to matching perceived heights, and rendered with strict nearest-neighbor sampling (no interpolation or blurring) on Retina displays. Jake faces right toward Holt.

### R2. HUD Layout & Visual Styling
Create a non-activating, floating horizontal HUD panel (~600–750 px wide × 110–150 px tall) with a dark translucent retro police terminal aesthetic. Jake occupies the left ~15–20%, Holt occupies the right ~15–20%, and the center contains 10 dynamic "COOL" volume slots rendered in crisp pixel typography with ghosted inactive slots.

### R3. Dynamic Pacing & Directional "COOL" Animation Engine
Implement an interruptible animation engine where increasing volume reveals "COOL" words traveling from Jake toward Holt with micro-delays (40–80 ms) and subtle 1–2 px pixel bounces. Repeated keypresses accelerate without queue latency. Decreasing volume rapidly flickers/dissolves words right-to-left.

### R4. Character Personality & Expressive States
Reflect character contrast: Jake becomes increasingly energetic as volume nears 100% (with optional celebratory bounce or "COOL...!" emphasis), while Holt remains unflinchingly composed and unimpressed. Implement subtle rare Easter eggs at 100% (e.g. Holt eyebrow shift or "Peralta." bubble; low-probability "NO DOUBT" or "BINGPOT!").

### R5. Mute/Unmute & Silence States
When muted, all COOLs clear immediately; after ~300 ms Holt displays a subtle "Silence." or "Finally." reaction. On unmute, rapidly rebuild the sequence back to the active volume within 250–400 ms.

### R6. System Integration & Performance
Integrate seamlessly into the existing `/Users/saumya/CustomVolumeHUD` architecture (`VolumeManager`, `MediaKeyInterceptor`, `HUDWindowController`):
- Authoritative synchronization with actual macOS system output volume.
- Suppress native macOS volume bezel via media key event tap.
- Floating `NSPanel` overlay that stays visible across full-screen spaces, clicks pass through, and never steals keyboard focus.
- Displays centered near the bottom of the active display containing the cursor.

## Acceptance Criteria

### Asset & Visual Quality
- [ ] Jake and Holt sprites have clean transparent backgrounds with original pixel edges preserved.
- [ ] Sprites render using nearest-neighbor sampling without any blurring on Retina displays.
- [ ] The HUD layout matches ~600–750 px wide by 110–150 px tall with Jake on the left and Holt on the right.
- [ ] 10 distinct "COOL" slots are clearly legible, using bright active text and dark ghosted inactive text.

### Animation & Responsiveness
- [ ] Stepping volume up reveals words sequentially from left to right with subtle pixel bounce.
- [ ] Stepping volume down dissolves words quickly from right to left.
- [ ] Rapid volume changes cancel stale animations and catch up to the authoritative volume in < 150 ms.
- [ ] Muting clears all words and shows the subtle Holt silence reaction; unmuting restores words within 400 ms.

### System & Build Integrity
- [ ] Project compiles cleanly with zero errors via `swift build`.
- [ ] Release script `./scripts/build_app.sh` bundles `CustomVolumeHUD.app` with `LSUIElement` enabled.
- [ ] Overlay floats over full-screen apps and does not steal focus or intercept mouse clicks.
