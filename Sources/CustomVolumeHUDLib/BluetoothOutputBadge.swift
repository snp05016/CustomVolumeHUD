import SwiftUI

/// Compact active-output badge shared by both Brooklyn Nine-Nine scenes.
struct BluetoothOutputBadge: View {
    let device: BluetoothOutputDevice
    let motionToken: Int
    let motionDirection: Int
    let isOutputSwitch: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var tilt: Double = 0
    @State private var iconScale: CGFloat = 1

    private var deviceImage: NSImage? {
        PixelAssetLoader.shared.image(named: device.assetName)
    }

    var body: some View {
        HStack(spacing: 3) {
            if let deviceImage {
                PixelArtSpriteView(image: deviceImage)
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(rotation + tilt))
                    .scaleEffect(iconScale)
            }

            PixelWordView(
                text: "BT // \(device.displayName)",
                pixelSize: 0.62,
                color: Color(red: 0.43, green: 0.88, blue: 1.0),
                shadowColor: .black,
                letterSpacing: 0.58
            )

            if let batteryPercentage = device.batteryPercentage {
                batteryStatus(percentage: batteryPercentage)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(red: 0.025, green: 0.07, blue: 0.12).opacity(0.96))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        )
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bluetooth audio output")
        .accessibilityValue(accessibilityValue)
        .task(id: motionToken) {
            guard !reduceMotion else { return }
            if isOutputSwitch {
                withAnimation(.easeInOut(duration: 0.42)) {
                    rotation += Double(motionDirection < 0 ? -360 : 360)
                    iconScale = 1.12
                }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                    iconScale = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.08)) {
                    tilt = Double(motionDirection < 0 ? -18 : 18)
                    iconScale = 1.10
                }
                try? await Task.sleep(for: .milliseconds(75))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                    tilt = 0
                    iconScale = 1
                }
            }
        }
    }

    private var isBatteryLow: Bool {
        guard let batteryPercentage = device.batteryPercentage else { return false }
        return batteryPercentage < 15
    }

    private var borderColor: Color {
        isBatteryLow
            ? Color(red: 1.0, green: 0.28, blue: 0.24).opacity(0.92)
            : Color(red: 0.25, green: 0.68, blue: 0.92).opacity(0.78)
    }

    private var accessibilityValue: String {
        guard let batteryPercentage = device.batteryPercentage else { return device.name }
        return "\(device.name), \(batteryPercentage) percent battery"
    }

    private func batteryStatus(percentage: Int) -> some View {
        HStack(spacing: 2) {
            PixelBatteryGauge(percentage: percentage)
            PixelWordView(
                text: "\(percentage)%",
                pixelSize: 0.58,
                color: isBatteryLow
                    ? Color(red: 1.0, green: 0.32, blue: 0.28)
                    : Color(red: 0.96, green: 0.78, blue: 0.25),
                shadowColor: .black,
                letterSpacing: 0.52
            )
        }
    }
}

private struct PixelBatteryGauge: View {
    let percentage: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index < filledBars ? fillColor : Color.white.opacity(0.13))
                    .frame(width: 2, height: 5)
            }
        }
        .padding(1)
        .overlay(Rectangle().stroke(fillColor.opacity(0.85), lineWidth: 1))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(fillColor.opacity(0.85))
                .frame(width: 1, height: 3)
                .offset(x: 2)
        }
    }

    private var filledBars: Int {
        min(4, max(0, Int(ceil(Double(percentage) / 25))))
    }

    private var fillColor: Color {
        percentage < 15
            ? Color(red: 1.0, green: 0.28, blue: 0.24)
            : Color(red: 0.96, green: 0.78, blue: 0.25)
    }
}

struct OutputSwitchBadge: View {
    let device: AudioOutputDevice

    var body: some View {
        HStack(spacing: 4) {
            PixelSpeakerGlyph()
                .frame(width: 16, height: 14)

            PixelWordView(
                text: "\(device.transportLabel) // \(device.displayName)",
                pixelSize: 0.60,
                color: Color(red: 0.43, green: 0.88, blue: 1.0),
                shadowColor: .black,
                letterSpacing: 0.56
            )
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(red: 0.025, green: 0.07, blue: 0.12).opacity(0.96))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color(red: 0.25, green: 0.68, blue: 0.92).opacity(0.78), lineWidth: 1)
            }
        )
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Audio output")
        .accessibilityValue(device.name)
    }
}

private struct PixelSpeakerGlyph: View {
    var body: some View {
        Canvas { context, _ in
            let cyan = Color(red: 0.43, green: 0.88, blue: 1.0)
            for rect in [
                CGRect(x: 1, y: 5, width: 4, height: 5),
                CGRect(x: 5, y: 3, width: 3, height: 9),
                CGRect(x: 8, y: 1, width: 2, height: 13),
                CGRect(x: 12, y: 4, width: 1, height: 7),
                CGRect(x: 14, y: 6, width: 1, height: 3)
            ] {
                context.fill(Path(rect), with: .color(cyan))
            }
        }
    }
}
