import SwiftUI

/// Compact pixel speech bubble shared by both Brooklyn Nine-Nine scenes.
public struct PixelSpeechBubble: View {
    public let text: String
    public let pointsLeft: Bool

    public init(text: String, pointsLeft: Bool = true) {
        self.text = text
        self.pointsLeft = pointsLeft
    }

    public var body: some View {
        HStack(spacing: 0) {
            if pointsLeft { pixelPointer(pointingLeft: true).offset(y: 3) }

            PixelWordView(
                text: text,
                pixelSize: 1.15,
                color: Color(red: 1.0, green: 0.95, blue: 0.70),
                shadowColor: .black,
                letterSpacing: 1.1
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(red: 0.035, green: 0.05, blue: 0.085).opacity(0.98))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color(red: 0.95, green: 0.75, blue: 0.25), lineWidth: 1)
                }
            )

            if !pointsLeft { pixelPointer(pointingLeft: false).offset(y: 3) }
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.65), radius: 3, x: 0, y: 2)
    }

    private func pixelPointer(pointingLeft: Bool) -> some View {
        Canvas { context, _ in
            let gold = Color(red: 0.95, green: 0.75, blue: 0.25)
            let dark = Color(red: 0.035, green: 0.05, blue: 0.085)
            let pixels: [CGRect]
            if pointingLeft {
                pixels = [
                    CGRect(x: 3, y: 0, width: 2, height: 2),
                    CGRect(x: 1, y: 2, width: 2, height: 2),
                    CGRect(x: 3, y: 4, width: 2, height: 2)
                ]
                context.fill(Path(CGRect(x: 3, y: 2, width: 2, height: 2)), with: .color(dark))
            } else {
                pixels = [
                    CGRect(x: 0, y: 0, width: 2, height: 2),
                    CGRect(x: 2, y: 2, width: 2, height: 2),
                    CGRect(x: 0, y: 4, width: 2, height: 2)
                ]
                context.fill(Path(CGRect(x: 0, y: 2, width: 2, height: 2)), with: .color(dark))
            }
            for pixel in pixels {
                context.fill(Path(pixel), with: .color(gold))
            }
        }
        .frame(width: 5, height: 6)
    }
}

/// Stable HUD shell. Each scene owns its own geometry and animation rendering.
public struct VolumeHUDView: View {
    @ObservedObject public var viewModel: VolumeHUDViewModel

    public static let hudWidth: CGFloat = 540
    public static let hudHeight: CGFloat = 116
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

    public var body: some View {
        ZStack {
            terminalBackground

            PixelVolumePill(
                progress: Double(viewModel.volume),
                isMuted: viewModel.isMuted,
                isFineAdjustment: viewModel.isFineAdjustment
            )
            .frame(width: 504, height: 8)
            .position(x: Self.hudWidth / 2, y: Self.hudHeight - 7)
            .zIndex(1)

            VStack(spacing: 1) {
                terminalHeader

                Group {
                    switch viewModel.currentSceneMode {
                    case .coolHolt:
                        CoolHoltSceneView(viewModel: viewModel)
                    case .runToTerry:
                        RunToTerrySceneView(viewModel: viewModel)
                    }
                }
                .frame(width: Self.hudWidth, height: 83)
            }
            .zIndex(2)

            dialogueLayer
        }
        .frame(width: Self.hudWidth, height: Self.hudHeight)
        .scaleEffect(viewModel.hudPulseScale)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.66), radius: 18, x: 0, y: 8)
    }

    private var dialogueLayer: some View {
        ZStack {
            switch viewModel.currentSceneMode {
            case .coolHolt:
                if let speech = viewModel.jakeSpeech {
                    PixelSpeechBubble(text: speech, pointsLeft: true)
                        .position(x: 133, y: 47)
                }
                if let speech = viewModel.holtSpeech {
                    PixelSpeechBubble(text: speech, pointsLeft: false)
                        .position(x: 404, y: 47)
                }

            case .runToTerry:
                if let speech = viewModel.runToTerryState.jakeSpeech {
                    let progressX = 75 + (viewModel.runToTerryState.visualProgress * 318)
                    PixelSpeechBubble(text: speech, pointsLeft: true)
                        .position(x: min(315, max(135, progressX + 56)), y: 45)
                }
                if let speech = viewModel.runToTerryState.terrySpeech {
                    PixelSpeechBubble(text: speech, pointsLeft: false)
                        .position(x: 385, y: 44)
                }
            }
        }
        .frame(width: Self.hudWidth, height: Self.hudHeight)
        .zIndex(20)
    }

    private var terminalHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))

            PixelWordView(
                text: "NYPD // 99TH",
                pixelSize: 0.85,
                color: Color(red: 0.95, green: 0.75, blue: 0.25),
                shadowColor: .black,
                letterSpacing: 0.85
            )
            .layoutPriority(2)

            Spacer(minLength: 6)

            if !hasDeviceBadge {
                PixelWordView(
                    text: viewModel.currentSceneMode == .coolHolt ? "COOL CONTROL" : "JAKE IN PURSUIT",
                    pixelSize: 0.85,
                    color: Color(red: 0.47, green: 0.69, blue: 0.91),
                    shadowColor: .black,
                    letterSpacing: 0.85
                )
                Spacer(minLength: 6)
            }

            if let bluetoothDevice = viewModel.bluetoothOutputDevice {
                BluetoothOutputBadge(
                    device: bluetoothDevice,
                    motionToken: viewModel.deviceIconMotionToken,
                    motionDirection: viewModel.deviceIconMotionDirection,
                    isOutputSwitch: viewModel.outputSwitchDevice?.isBluetooth == true
                )
                .layoutPriority(1)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if let outputDevice = viewModel.outputSwitchDevice {
                OutputSwitchBadge(device: outputDevice)
                    .layoutPriority(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Spacer(minLength: 6)

            PixelWordView(
                text: viewModel.isMuted ? "[ MUTED ]" : "LEVEL: \(Int(round(viewModel.volume * 100)))%",
                pixelSize: 0.85,
                color: viewModel.isMuted
                    ? Color(red: 1.0, green: 0.35, blue: 0.35)
                    : Color(red: 0.40, green: 0.90, blue: 1.0),
                shadowColor: .black,
                letterSpacing: 0.85
            )
            .layoutPriority(2)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .animation(.easeOut(duration: 0.16), value: viewModel.bluetoothOutputDevice)
    }

    private var hasDeviceBadge: Bool {
        viewModel.bluetoothOutputDevice != nil || viewModel.outputSwitchDevice != nil
    }

    private var terminalBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.035, green: 0.05, blue: 0.085).opacity(0.965))

            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                        with: .color(.black.opacity(0.18))
                    )
                    y += 3
                }

                let corner = Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.7)
                for point in [
                    CGPoint(x: 7, y: 7), CGPoint(x: size.width - 9, y: 7),
                    CGPoint(x: 7, y: size.height - 9), CGPoint(x: size.width - 9, y: size.height - 9)
                ] {
                    context.fill(Path(CGRect(origin: point, size: CGSize(width: 2, height: 2))), with: .color(corner))
                }
            }

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.70, blue: 0.25).opacity(0.72),
                            Color(red: 0.20, green: 0.45, blue: 0.75).opacity(0.48),
                            Color(red: 0.85, green: 0.70, blue: 0.25).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                .padding(1)
        }
    }
}
