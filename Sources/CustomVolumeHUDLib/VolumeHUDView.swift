import SwiftUI

/// Retro Police Terminal Speech Bubble for Brooklyn Nine-Nine characters.
public struct PixelSpeechBubble: View {
    public let text: String
    public let pointsLeft: Bool

    public init(text: String, pointsLeft: Bool = true) {
        self.text = text
        self.pointsLeft = pointsLeft
    }

    public var body: some View {
        HStack(spacing: 0) {
            if pointsLeft {
                // Pixel pointer on left pointing towards Jake
                pixelPointer(pointingLeft: true)
                    .offset(y: 3)
            }

            // Main bubble box
            HStack(spacing: 4) {
                PixelWordView(
                    text: text,
                    pixelSize: 1.5,
                    color: Color(red: 1.0, green: 0.95, blue: 0.7),
                    shadowColor: Color.black,
                    letterSpacing: 1.5
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.06, green: 0.08, blue: 0.13).opacity(0.95))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(red: 0.95, green: 0.75, blue: 0.25), lineWidth: 1.2)
                }
            )

            if !pointsLeft {
                // Pixel pointer on right pointing towards Holt
                pixelPointer(pointingLeft: false)
                    .offset(y: 3)
            }
        }
        .fixedSize()
        .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)
    }

    private func pixelPointer(pointingLeft: Bool) -> some View {
        Canvas { context, _ in
            let gold = Color(red: 0.95, green: 0.75, blue: 0.25)
            let dark = Color(red: 0.06, green: 0.08, blue: 0.13)
            if pointingLeft {
                // < shape pointing left
                context.fill(Path(CGRect(x: 3, y: 0, width: 2, height: 2)), with: .color(gold))
                context.fill(Path(CGRect(x: 1, y: 2, width: 2, height: 2)), with: .color(gold))
                context.fill(Path(CGRect(x: 3, y: 4, width: 2, height: 2)), with: .color(gold))
                context.fill(Path(CGRect(x: 3, y: 2, width: 2, height: 2)), with: .color(dark))
            } else {
                // > shape pointing right
                context.fill(Path(CGRect(x: 0, y: 0, width: 2, height: 2)), with: .color(gold))
                context.fill(Path(CGRect(x: 2, y: 2, width: 2, height: 2)), with: .color(gold))
                context.fill(Path(CGRect(x: 0, y: 4, width: 2, height: 2)), with: .color(gold))
                context.fill(Path(CGRect(x: 0, y: 2, width: 2, height: 2)), with: .color(dark))
            }
        }
        .frame(width: 5, height: 6)
    }
}

/// Brooklyn Nine-Nine themed macOS volume HUD featuring pixel-art Jake Peralta
/// and Captain Raymond Holt with dynamic "COOL" volume steps.
public struct VolumeHUDView: View {
    @ObservedObject public var viewModel: VolumeHUDViewModel

    public init(viewModel: VolumeHUDViewModel) {
        self.viewModel = viewModel
    }

    public init(volume: Float, isMuted: Bool) {
        self.viewModel = VolumeHUDViewModel(volume: volume, isMuted: isMuted)
    }

    private var jakeImage: NSImage? {
        PixelAssetLoader.shared.image(named: "jake")
    }

    private var holtImage: NSImage? {
        let name = viewModel.holtEyebrowRaised ? "holt_eyebrow" : "holt"
        return PixelAssetLoader.shared.image(named: name)
    }

    public var body: some View {
        ZStack {
            // Base terminal bezel & scanlines
            terminalBackground

            VStack(spacing: 4) {
                // Top terminal header
                terminalHeader

                // Main character + COOL slots row
                HStack(alignment: .bottom, spacing: 8) {
                    // Left: Jake Peralta (~16% of width)
                    jakeSection
                        .frame(width: 80, height: 96, alignment: .bottom)

                    // Center: 10 "COOL" volume slots (~68% of width)
                    slotsSection
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Right: Captain Raymond Holt (~16% of width)
                    holtSection
                        .frame(width: 80, height: 96, alignment: .bottom)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            // Dialogue layer floating neatly in the center area above COOL slots
            dialogueLayer
        }
        .frame(width: 680, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
    }

    // MARK: - Subviews

    private var dialogueLayer: some View {
        ZStack {
            if let speech = viewModel.jakeSpeech {
                PixelSpeechBubble(text: speech, pointsLeft: true)
                    .position(x: 160, y: 58)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
            }

            if let speech = viewModel.holtSpeech {
                PixelSpeechBubble(text: speech, pointsLeft: false)
                    .position(x: 520, y: 58)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .frame(width: 680, height: 136)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.jakeSpeech)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.holtSpeech)
    }

    private var terminalBackground: some View {
        ZStack {
            // Dark translucent acrylic backing
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.94))

            // Subtle scanlines overlay
            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(Color.black.opacity(0.20)))
                    y += 3
                }
            }

            // Retro police terminal double border
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.70, blue: 0.25).opacity(0.6), // NYPD Gold
                            Color(red: 0.20, green: 0.45, blue: 0.75).opacity(0.4), // Police Blue
                            Color(red: 0.85, green: 0.70, blue: 0.25).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Inner thin bevel
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                .padding(1)
        }
    }

    private var terminalHeader: some View {
        HStack(spacing: 8) {
            // Left: Precinct Badge & Identifier
            HStack(spacing: 5) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))

                PixelWordView(
                    text: "NYPD // 99TH PRECINCT",
                    pixelSize: 1.0,
                    color: Color(red: 0.95, green: 0.75, blue: 0.25),
                    shadowColor: Color.black,
                    letterSpacing: 1.0
                )
            }

            Spacer()

            // Center: Monitor tag
            PixelWordView(
                text: "AUDIO LEVEL MONITOR",
                pixelSize: 1.0,
                color: Color.white.opacity(0.55),
                shadowColor: Color.black,
                letterSpacing: 1.0
            )

            Spacer()

            // Right: Level Readout
            HStack(spacing: 4) {
                if viewModel.isMuted {
                    PixelWordView(
                        text: "[ MUTED ]",
                        pixelSize: 1.0,
                        color: Color(red: 1.0, green: 0.35, blue: 0.35),
                        shadowColor: Color.black,
                        letterSpacing: 1.0
                    )
                } else {
                    let pct = Int(round(viewModel.volume * 100))
                    PixelWordView(
                        text: "LEVEL: \(pct)%",
                        pixelSize: 1.0,
                        color: Color(red: 0.4, green: 0.9, blue: 1.0),
                        shadowColor: Color.black,
                        letterSpacing: 1.0
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 9)
    }

    private var jakeSection: some View {
        ZStack(alignment: .bottom) {
            // Jake Sprite facing right toward Holt
            if let img = jakeImage {
                PixelArtSpriteView(image: img, isFlippedHorizontal: false)
                    .frame(width: 54, height: 92)
                    .offset(y: viewModel.jakeBounceY)
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: viewModel.jakeBounceY)
            } else {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 54, height: 92)
            }
        }
    }

    private var holtSection: some View {
        ZStack(alignment: .bottom) {
            // Captain Holt Sprite facing left toward Jake
            if let img = holtImage {
                PixelArtSpriteView(image: img, isFlippedHorizontal: false)
                    .frame(width: 44, height: 96)
            } else {
                Rectangle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 44, height: 96)
            }
        }
    }

    private var slotsSection: some View {
        HStack(spacing: 4) {
            ForEach(0..<VolumeHUDViewModel.maxSlots, id: \.self) { index in
                volumeSlot(at: index)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func volumeSlot(at index: Int) -> some View {
        let isActive = index < viewModel.displayedCount
        let bounceY = viewModel.slotBounces[index]
        let slotOpacity = viewModel.slotOpacities[index]
        let effectiveOpacity = slotOpacity > 0.0 ? slotOpacity : (isActive ? 1.0 : 0.0)

        VStack(spacing: 4) {
            // The "COOL" slot container
            ZStack {
                // Ghosted Inactive Base box (always visible underneath)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(white: 0.08).opacity(0.6))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color(white: 0.2).opacity(0.35), lineWidth: 1.0)

                PixelWordView(
                    text: "COOL",
                    pixelSize: 1.6,
                    color: Color(red: 0.22, green: 0.28, blue: 0.38).opacity(0.40),
                    shadowColor: nil,
                    letterSpacing: 1.4
                )

                // Active luminous layer with CRT phosphor dissolve & flicker opacity
                if isActive || slotOpacity > 0.0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.9))

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.75), lineWidth: 1.0)

                        PixelWordView(
                            text: "COOL",
                            pixelSize: 1.6,
                            color: Color(red: 1.0, green: 0.90, blue: 0.35),
                            shadowColor: Color.black.opacity(0.8),
                            letterSpacing: 1.4
                        )
                        .offset(y: bounceY)
                    }
                    .opacity(effectiveOpacity)
                }
            }
            .frame(width: 42, height: 28)

            // Bottom LED indicator bar
            ZStack {
                Rectangle()
                    .fill(Color(white: 0.18).opacity(0.4))

                if isActive || slotOpacity > 0.0 {
                    Rectangle()
                        .fill(Color(red: 0.95, green: 0.78, blue: 0.25))
                        .opacity(effectiveOpacity)
                }
            }
            .frame(width: 38, height: 2.5)
            .cornerRadius(1)
        }
    }
}
