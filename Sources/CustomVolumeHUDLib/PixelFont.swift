import SwiftUI

/// 5x7 Bitmap Pixel Font Engine for crisp pixel art typography.
public enum PixelFont {
    /// Each glyph is defined as 7 rows of 5-bit masks (bits 4..0).
    public static let glyphs: [Character: [UInt8]] = [
        "A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "B": [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110],
        "C": [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110],
        "D": [0b11100, 0b10010, 0b10001, 0b10001, 0b10001, 0b10010, 0b11100],
        "E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
        "F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
        "G": [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110],
        "H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "I": [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "J": [0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100],
        "K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
        "L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
        "M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
        "N": [0b10001, 0b11001, 0b10101, 0b10101, 0b10011, 0b10001, 0b10001],
        "O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
        "Q": [0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101],
        "R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
        "S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
        "T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
        "U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "V": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100],
        "W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001],
        "X": [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001],
        "Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
        "Z": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111],
        "0": [0b01110, 0b10011, 0b10101, 0b10101, 0b11001, 0b10001, 0b01110],
        "1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "2": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111],
        "3": [0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110],
        "4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
        "5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
        "6": [0b01110, 0b10000, 0b11110, 0b10001, 0b10001, 0b10001, 0b01110],
        "7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
        "8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
        "9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110],
        "!": [0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100],
        "?": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b00000, 0b00100],
        ".": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00100],
        ":": [0b00000, 0b00100, 0b00000, 0b00000, 0b00100, 0b00000, 0b00000],
        "-": [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000],
        "/": [0b00001, 0b00010, 0b00100, 0b00100, 0b01000, 0b10000, 0b00000],
        "%": [0b11001, 0b11010, 0b00100, 0b01000, 0b01011, 0b10011, 0b00000],
        "[": [0b01110, 0b01000, 0b01000, 0b01000, 0b01000, 0b01000, 0b01110],
        "]": [0b01110, 0b00010, 0b00010, 0b00010, 0b00010, 0b00010, 0b01110],
        ",": [0b00000, 0b00000, 0b00000, 0b00000, 0b00100, 0b00100, 0b01000],
        "'": [0b00100, 0b00100, 0b01000, 0b00000, 0b00000, 0b00000, 0b00000],
        "\"": [0b01010, 0b01010, 0b10100, 0b00000, 0b00000, 0b00000, 0b00000],
        "(": [0b00010, 0b00100, 0b01000, 0b01000, 0b01000, 0b00100, 0b00010],
        ")": [0b01000, 0b00100, 0b00010, 0b00010, 0b00010, 0b00100, 0b01000],
        ";": [0b00000, 0b00100, 0b00000, 0b00000, 0b00100, 0b00100, 0b01000],
        " ": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000]
    ]

    public static func glyph(for char: Character) -> [UInt8] {
        let upper = Character(char.uppercased())
        return glyphs[upper] ?? glyphs[" "]!
    }
}

/// A SwiftUI view that renders text with true crisp bitmap pixels.
public struct PixelWordView: View {
    public let text: String
    public let pixelSize: CGFloat
    public let color: Color
    public let shadowColor: Color?
    public let letterSpacing: CGFloat

    public init(
        text: String,
        pixelSize: CGFloat = 2.0,
        color: Color = .white,
        shadowColor: Color? = nil,
        letterSpacing: CGFloat = 2.0
    ) {
        self.text = text
        self.pixelSize = pixelSize
        self.color = color
        self.shadowColor = shadowColor
        self.letterSpacing = letterSpacing
    }

    private var totalWidth: CGFloat {
        let charCount = CGFloat(text.count)
        guard charCount > 0 else { return 0 }
        let glyphWidth = 5.0 * pixelSize
        let baseWidth = (charCount * glyphWidth) + ((charCount - 1) * letterSpacing)
        return shadowColor != nil ? baseWidth + 1.0 : baseWidth
    }

    private var totalHeight: CGFloat {
        let baseHeight = 7.0 * pixelSize
        return shadowColor != nil ? baseHeight + 1.0 : baseHeight
    }

    public var body: some View {
        Canvas { context, size in
            var startX: CGFloat = 0

            for char in text {
                let mask = PixelFont.glyph(for: char)

                // Optional 1-pixel shadow
                if let shadow = shadowColor {
                    for row in 0..<7 {
                        let rowBits = mask[row]
                        for col in 0..<5 {
                            let bit = (rowBits >> (4 - col)) & 1
                            if bit == 1 {
                                let rect = CGRect(
                                    x: startX + CGFloat(col) * pixelSize + 1.0,
                                    y: CGFloat(row) * pixelSize + 1.0,
                                    width: pixelSize,
                                    height: pixelSize
                                )
                                context.fill(Path(rect), with: .color(shadow))
                            }
                        }
                    }
                }

                // Main pixel fill
                for row in 0..<7 {
                    let rowBits = mask[row]
                    for col in 0..<5 {
                        let bit = (rowBits >> (4 - col)) & 1
                        if bit == 1 {
                            let rect = CGRect(
                                x: startX + CGFloat(col) * pixelSize,
                                y: CGFloat(row) * pixelSize,
                                width: pixelSize,
                                height: pixelSize
                            )
                            context.fill(Path(rect), with: .color(color))
                        }
                    }
                }

                startX += (5.0 * pixelSize) + letterSpacing
            }
        }
        .frame(width: totalWidth, height: totalHeight)
    }
}
