import SwiftUI

/// Modern, sleek floating Volume HUD view.
struct VolumeHUDView: View {
    var volume: Float
    var isMuted: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isMuted ? .red.opacity(0.85) : .white)
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.15), value: isMuted)

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.18))

                    // Progress Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isMuted ? [Color.red.opacity(0.6), Color.red.opacity(0.8)] : [Color.white, Color.white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth(totalWidth: geometry.size.width))
                        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.8), value: volume)
                        .animation(.easeInOut(duration: 0.15), value: isMuted)
                }
            }
            .frame(height: 7)

            // Percentage Label
            Text(percentageText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 240, height: 46)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    private func fillWidth(totalWidth: CGFloat) -> CGFloat {
        if isMuted { return 0 }
        let clamped = max(0.0, min(1.0, CGFloat(volume)))
        return totalWidth * clamped
    }

    private var percentageText: String {
        if isMuted {
            return "Mute"
        }
        let percent = Int(round(volume * 100))
        return "\(percent)%"
    }

    private var iconName: String {
        if isMuted || volume <= 0.001 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
