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
            HStack(spacing: 3) {
                PixelWordView(
                    text: text,
                    pixelSize: 1.2,
                    color: Color(red: 1.0, green: 0.95, blue: 0.7),
                    shadowColor: Color.black,
                    letterSpacing: 1.2
                )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
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

    public static let hudWidth: CGFloat = 540
    public static let hudHeight: CGFloat = 108
    public static let slotWidth: CGFloat = 34
    public static let slotHeight: CGFloat = 22
    public static let slotPixelSize: CGFloat = 1.25
    public static let slotLetterSpacing: CGFloat = 1.1

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

            VStack(spacing: 3) {
                // Top terminal header
                terminalHeader

                // Main character + COOL slots row
                HStack(alignment: .bottom, spacing: 6) {
                    // Left: Jake Peralta (~16% of width)
                    jakeSection
                        .frame(width: 64, height: 76, alignment: .bottom)

                    // Center: 10 "COOL" volume slots (~68% of width)
                    slotsSection
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Right: Captain Raymond Holt (~16% of width)
                    holtSection
                        .frame(width: 64, height: 76, alignment: .bottom)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Dialogue layer floating neatly in the center area above COOL slots
            dialogueLayer
        }
        .frame(width: Self.hudWidth, height: Self.hudHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.black.opacity(0.65), radius: 18, x: 0, y: 8)
    }

    // MARK: - Subviews

    private var dialogueLayer: some View {
        ZStack {
            if let speech = viewModel.jakeSpeech {
                PixelSpeechBubble(text: speech, pointsLeft: true)
                    .position(x: 130, y: 46)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
            }

            if let speech = viewModel.holtSpeech {
                PixelSpeechBubble(text: speech, pointsLeft: false)
                    .position(x: 410, y: 46)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .frame(width: Self.hudWidth, height: Self.hudHeight)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.jakeSpeech)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.holtSpeech)
    }

    private var terminalBackground: some View {
        ZStack {
            // Dark translucent acrylic backing
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                .padding(1)
        }
    }

    private var terminalHeader: some View {
        HStack(spacing: 6) {
            // Left: Precinct Badge & Identifier
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))

                PixelWordView(
                    text: "NYPD // 99TH PRECINCT",
                    pixelSize: 0.85,
                    color: Color(red: 0.95, green: 0.75, blue: 0.25),
                    shadowColor: Color.black,
                    letterSpacing: 0.85
                )
            }

            Spacer()

            // Center: Monitor tag
            PixelWordView(
                text: "AUDIO LEVEL MONITOR",
                pixelSize: 0.85,
                color: Color.white.opacity(0.55),
                shadowColor: Color.black,
                letterSpacing: 0.85
            )

            Spacer()

            // Right: Level Readout
            HStack(spacing: 3) {
                if viewModel.isMuted {
                    PixelWordView(
                        text: "[ MUTED ]",
                        pixelSize: 0.85,
                        color: Color(red: 1.0, green: 0.35, blue: 0.35),
                        shadowColor: Color.black,
                        letterSpacing: 0.85
                    )
                } else {
                    let pct = Int(round(viewModel.volume * 100))
                    PixelWordView(
                        text: "LEVEL: \(pct)%",
                        pixelSize: 0.85,
                        color: Color(red: 0.4, green: 0.9, blue: 1.0),
                        shadowColor: Color.black,
                        letterSpacing: 0.85
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var jakeSection: some View {
        ZStack(alignment: .bottom) {
            // Jake Sprite facing right toward Holt
            if let img = jakeImage {
                PixelArtSpriteView(image: img, isFlippedHorizontal: false)
                    .frame(width: 44, height: 72)
                    .offset(y: viewModel.jakeBounceY)
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: viewModel.jakeBounceY)
            } else {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 44, height: 72)
            }
        }
    }

    private var holtSection: some View {
        ZStack(alignment: .bottom) {
            // Captain Holt Sprite facing left toward Jake
            if let img = holtImage {
                PixelArtSpriteView(image: img, isFlippedHorizontal: false)
                    .frame(width: 36, height: 76)
            } else {
                Rectangle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 36, height: 76)
            }
        }
    }

    private var slotsSection: some View {
        HStack(spacing: 3) {
            ForEach(0..<VolumeHUDViewModel.maxSlots, id: \.self) { index in
                volumeSlot(at: index)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func volumeSlot(at index: Int) -> some View {
        let isActive = index < viewModel.displayedCount
        let bounceY = viewModel.slotBounces[index]
        let slotOpacity = viewModel.slotOpacities[index]
        let effectiveOpacity = slotOpacity > 0.0 ? slotOpacity : (isActive ? 1.0 : 0.0)

        VStack(spacing: 3) {
            // The "COOL" slot container
            ZStack {
                // Ghosted Inactive Base box (always visible underneath)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(white: 0.08).opacity(0.6))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color(white: 0.2).opacity(0.35), lineWidth: 0.8)

                PixelWordView(
                    text: "COOL",
                    pixelSize: Self.slotPixelSize,
                    color: Color(red: 0.22, green: 0.28, blue: 0.38).opacity(0.40),
                    shadowColor: nil,
                    letterSpacing: Self.slotLetterSpacing
                )

                // Active luminous layer with CRT phosphor dissolve & flicker opacity
                if isActive || slotOpacity > 0.0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.9))

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.75), lineWidth: 0.8)

                        PixelWordView(
                            text: "COOL",
                            pixelSize: Self.slotPixelSize,
                            color: Color(red: 1.0, green: 0.90, blue: 0.35),
                            shadowColor: Color.black.opacity(0.8),
                            letterSpacing: Self.slotLetterSpacing
                        )
                        .offset(y: bounceY)
                    }
                    .opacity(effectiveOpacity)
                }
            }
            .frame(width: Self.slotWidth, height: Self.slotHeight)

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
            .frame(width: 30, height: 2)
            .cornerRadius(1)
        }
    }
}
