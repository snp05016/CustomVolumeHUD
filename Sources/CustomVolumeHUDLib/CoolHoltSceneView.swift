import SwiftUI

/// Original Jake/Holt COOL visualization, kept isolated from the Terry running scene.
struct CoolHoltSceneView: View {
    @ObservedObject var viewModel: VolumeHUDViewModel

    private var jakeImage: NSImage? { PixelAssetLoader.shared.image(named: "jake") }
    private var holtImage: NSImage? {
        PixelAssetLoader.shared.image(named: viewModel.holtEyebrowRaised ? "holt_eyebrow" : "holt")
    }
    private var cheddarImage: NSImage? { PixelAssetLoader.shared.image(named: "cheddar") }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: 6) {
                jakeSection
                    .frame(width: 60, height: 76, alignment: .bottom)

                slotsSection
                    .frame(maxWidth: .infinity, alignment: .center)

                holtSection
                    .frame(width: 52, height: 76, alignment: .bottom)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 3)

            if viewModel.cheddarActive, let cheddarImage {
                PixelArtSpriteView(image: cheddarImage)
                    .frame(width: 22, height: 14)
                    .position(x: round(viewModel.cheddarPositionX), y: 72)
                    .zIndex(10)
            }
        }
    }

    private var jakeSection: some View {
        ZStack(alignment: .bottom) {
            if let jakeImage {
                PixelArtSpriteView(image: jakeImage)
                    .frame(width: 44, height: 72)
                    .offset(
                        x: round(viewModel.jakeLeanX + viewModel.jakeMicroOffsetX),
                        y: round(viewModel.jakeBounceY + viewModel.jakeMicroTiptoeY)
                    )
            }

            if viewModel.comboCount >= 4 {
                PixelWordView(
                    text: "x\(viewModel.comboCount)",
                    pixelSize: 0.85,
                    color: Color(red: 1.0, green: 0.85, blue: 0.30),
                    shadowColor: .black,
                    letterSpacing: 0.85
                )
                .offset(x: 17, y: -58)
            }
        }
    }

    private var holtSection: some View {
        ZStack(alignment: .bottom) {
            if let holtImage {
                PixelArtSpriteView(image: holtImage)
                    .frame(width: 36, height: 76)
                    .offset(x: round(viewModel.holtEyeShift))
            }
        }
    }

    private var slotsSection: some View {
        HStack(spacing: 2) {
            ForEach(0..<VolumeHUDViewModel.maxSlots, id: \.self) { index in
                volumeSlot(at: index)
            }

            if viewModel.overflowCoolCount > 0 {
                overflowStackSection
            }
        }
        .padding(.vertical, 4)
    }

    private var overflowStackSection: some View {
        ZStack {
            ForEach(0..<viewModel.overflowCoolCount, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.88))

                    PixelWordView(
                        text: "COOL",
                        pixelSize: 0.9,
                        color: Color(red: 0.08, green: 0.10, blue: 0.16),
                        letterSpacing: 0.8
                    )
                }
                .frame(width: 24, height: 16)
                .offset(
                    x: round(viewModel.overflowOffsetsX[index] - CGFloat(index * 3)),
                    y: round(viewModel.overflowJiggleY[index])
                )
            }
        }
        .frame(width: 26, height: 22)
    }

    @ViewBuilder
    private func volumeSlot(at index: Int) -> some View {
        let isActive = index < viewModel.displayedCount
        let slotOpacity = viewModel.slotOpacities[index]
        let effectiveOpacity = slotOpacity > 0 ? slotOpacity : (isActive ? 1 : 0)

        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(white: 0.08).opacity(0.62))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color(white: 0.22).opacity(0.38), lineWidth: 0.8)

                PixelWordView(
                    text: "COOL",
                    pixelSize: VolumeHUDView.slotPixelSize,
                    color: Color(red: 0.22, green: 0.28, blue: 0.38).opacity(0.42),
                    letterSpacing: VolumeHUDView.slotLetterSpacing
                )

                if isActive || slotOpacity > 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.93))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(
                                Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.80),
                                lineWidth: 0.8
                            )
                        PixelWordView(
                            text: "COOL",
                            pixelSize: VolumeHUDView.slotPixelSize,
                            color: Color(red: 1.0, green: 0.90, blue: 0.35),
                            shadowColor: .black.opacity(0.8),
                            letterSpacing: VolumeHUDView.slotLetterSpacing
                        )
                        .offset(
                            x: round(viewModel.slotOffsetsX[index]),
                            y: round(viewModel.slotBounces[index])
                        )
                    }
                    .scaleEffect(viewModel.slotScales[index])
                    .opacity(effectiveOpacity)
                }
            }
            .frame(width: VolumeHUDView.slotWidth, height: VolumeHUDView.slotHeight)

            ZStack {
                Rectangle().fill(Color(white: 0.18).opacity(0.42))
                if isActive || slotOpacity > 0 {
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
