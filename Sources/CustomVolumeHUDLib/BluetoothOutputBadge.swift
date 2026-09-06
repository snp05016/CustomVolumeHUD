import SwiftUI

/// Compact active-output badge shared by both Brooklyn Nine-Nine scenes.
struct BluetoothOutputBadge: View {
    let device: BluetoothOutputDevice

    private var deviceImage: NSImage? {
        PixelAssetLoader.shared.image(named: device.assetName)
    }

    var body: some View {
        HStack(spacing: 3) {
            if let deviceImage {
                PixelArtSpriteView(image: deviceImage)
                    .frame(width: 16, height: 16)
            }

            PixelWordView(
                text: "BT // \(device.displayName)",
                pixelSize: 0.62,
                color: Color(red: 0.43, green: 0.88, blue: 1.0),
                shadowColor: .black,
                letterSpacing: 0.58
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
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
        .accessibilityLabel("Bluetooth audio output")
        .accessibilityValue(device.name)
    }
}
