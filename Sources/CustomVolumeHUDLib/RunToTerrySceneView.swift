import SwiftUI

/// Jake's continuous distance to Terry is the volume indicator in this scene.
struct RunToTerrySceneView: View {
    @ObservedObject var viewModel: VolumeHUDViewModel

    private let startX: CGFloat = 66
    private let endX: CGFloat = 394
    private let terryX: CGFloat = 474

    private var state: RunToTerryRenderState { viewModel.runToTerryState }
    private var jakeImage: NSImage? {
        if !state.isMoving {
            return PixelAssetLoader.shared.image(named: "jake")
        }
        return PixelAssetLoader.shared.image(named: state.frameIndex == 0 ? "jake_run_1" : "jake_run_2")
    }
    private var terryImage: NSImage? { PixelAssetLoader.shared.image(named: "terry_standing") }
    private var catchImage: NSImage? { PixelAssetLoader.shared.image(named: "terry_catch") }

    var body: some View {
        ZStack(alignment: .topLeading) {
            precinctFloor

            if state.isCaught {
                if let catchImage {
                    PixelArtSpriteView(image: catchImage)
                        .frame(width: 68, height: 84)
                        .scaleEffect(state.catchScale)
                        .position(x: 464, y: 41)
                        .offset(y: round(state.catchOffsetY))
                }
            } else {
                if let terryImage {
                    PixelArtSpriteView(image: terryImage)
                        .frame(width: 50, height: 77)
                        .position(x: terryX, y: 42)
                        .offset(y: round(state.terryOffsetY))
                }

                if let jakeImage {
                    PixelArtSpriteView(
                        image: jakeImage,
                        isFlippedHorizontal: state.isMoving && state.direction < 0
                    )
                    .frame(
                        width: state.isMoving ? 70 : 44,
                        height: state.isMoving ? 60 : 72
                    )
                    .position(x: snappedJakeX, y: state.isMoving ? 48 : 42)
                    .offset(
                        x: round(state.jakeLeanX),
                        y: round(state.jakeOffsetY)
                    )
                }
            }

            if viewModel.comboCount >= 4 && !state.isCaught {
                PixelWordView(
                    text: "RUN x\(viewModel.comboCount)",
                    pixelSize: 0.75,
                    color: Color(red: 1.0, green: 0.83, blue: 0.27),
                    shadowColor: .black,
                    letterSpacing: 0.75
                )
                .position(x: 270, y: 70)
            }
        }
        .frame(width: VolumeHUDView.hudWidth, height: 83)
        .clipped()
    }

    private var snappedJakeX: CGFloat {
        let progress = CGFloat(max(0, min(1, state.visualProgress)))
        return round(startX + ((endX - startX) * progress))
    }

    private var precinctFloor: some View {
        Canvas { context, size in
            let baselineY: CGFloat = 76
            context.fill(
                Path(CGRect(x: 34, y: baselineY, width: size.width - 68, height: 1)),
                with: .color(Color(red: 0.18, green: 0.33, blue: 0.52).opacity(0.48))
            )

            var x: CGFloat = 48
            while x < size.width - 40 {
                context.fill(
                    Path(CGRect(x: x, y: baselineY - 2, width: 8, height: 2)),
                    with: .color(Color(red: 0.92, green: 0.72, blue: 0.23).opacity(0.22))
                )
                x += 26
            }

            // A small collision marker grounds the catch without becoming a progress bar.
            context.fill(
                Path(CGRect(x: terryX - 24, y: baselineY - 4, width: 2, height: 4)),
                with: .color(Color(red: 0.92, green: 0.72, blue: 0.23).opacity(0.55))
            )
        }
    }
}
