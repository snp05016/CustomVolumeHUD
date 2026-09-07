import SwiftUI

/// A compact, pixel-accented conventional readout that supports both character scenes.
struct PixelVolumePill: View {
    let progress: Double
    let isMuted: Bool
    let isFineAdjustment: Bool

    private var clampedProgress: CGFloat {
        isMuted ? 0 : CGFloat(max(0, min(1, progress)))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let inset: CGFloat = 2
            let innerWidth = max(0, width - (inset * 2))
            let fillWidth = innerWidth * clampedProgress

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.025, green: 0.04, blue: 0.07).opacity(0.96))

                Capsule(style: .continuous)
                    .strokeBorder(
                        isMuted
                            ? Color(red: 0.95, green: 0.28, blue: 0.28).opacity(0.75)
                            : Color(red: 0.28, green: 0.52, blue: 0.78).opacity(0.72),
                        lineWidth: 1
                    )

                if fillWidth > 0 {
                    RoundedRectangle(cornerRadius: max(1, (height - 4) / 2), style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.62, blue: 0.88),
                                    Color(red: 0.96, green: 0.76, blue: 0.22)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(height - 4, fillWidth), height: max(2, height - 4))
                        .padding(inset)
                }

                ForEach(1..<10, id: \.self) { index in
                    Rectangle()
                        .fill(Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.65))
                        .frame(width: 1, height: max(2, height - 4))
                        .position(x: width * CGFloat(index) / 10, y: height / 2)
                }

                // 64 native macOS positions: every fourth mark is one normal 1/16 step.
                ForEach(1..<64, id: \.self) { index in
                    let standardBoundary = index.isMultiple(of: 4)
                    Rectangle()
                        .fill(
                            isFineAdjustment
                                ? Color(red: 0.44, green: 0.92, blue: 1.0).opacity(standardBoundary ? 0.66 : 0.34)
                                : Color.white.opacity(standardBoundary ? 0.24 : 0.10)
                        )
                        .frame(
                            width: standardBoundary ? 1 : 0.5,
                            height: max(1, height - (standardBoundary ? 3 : 5))
                        )
                        .position(x: width * CGFloat(index) / 64, y: height / 2)
                }

                if clampedProgress > 0 {
                    Rectangle()
                        .fill(Color(red: 1.0, green: 0.94, blue: 0.62))
                        .frame(width: 1, height: max(2, height - 4))
                        .position(
                            x: min(width - inset, inset + fillWidth),
                            y: height / 2
                        )
                }
            }
        }
        .animation(.easeOut(duration: 0.14), value: clampedProgress)
        .animation(.easeOut(duration: 0.12), value: isFineAdjustment)
        .accessibilityLabel("Volume")
        .accessibilityValue(isMuted ? "Muted" : "\(Int(round(progress * 100))) percent")
    }
}
