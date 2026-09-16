import AppKit
import SwiftUI

/// Manages and caches pixel art sprite assets with multiple bundle fallbacks.
public final class PixelAssetLoader: @unchecked Sendable {
    public static let shared = PixelAssetLoader()
    private let lock = NSLock()
    private var cache: [String: NSImage] = [:]

    private init() {}

    public func image(named name: String) -> NSImage? {
        lock.lock()
        if let cached = cache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let img = loadImage(named: name)
        if let img = img {
            lock.lock()
            cache[name] = img
            lock.unlock()
        }
        return img
    }

    private func loadImage(named name: String) -> NSImage? {
        let filename = name.hasSuffix(".png") ? name : "\(name).png"

        // 1. Check Bundle.module (SwiftPM resource bundle)
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: name, withExtension: "png") {
            if let img = NSImage(contentsOf: url) { return img }
        }
        #endif

        // 2. Check Bundle.main
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            if let img = NSImage(contentsOf: url) { return img }
        }

        // 3. Check Bundle.main/Contents/Resources
        if let resourceURL = Bundle.main.resourceURL {
            let directURL = resourceURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: directURL.path),
               let img = NSImage(contentsOf: directURL) {
                return img
            }
        }

        // 4. Check all bundles inside main bundle resources or bundle URL
        if let resourceURL = Bundle.main.resourceURL {
            let bundleURLs = (try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)) ?? []
            for bundleURL in bundleURLs where bundleURL.pathExtension == "bundle" {
                if let bundle = Bundle(url: bundleURL),
                   let url = bundle.url(forResource: name, withExtension: "png"),
                   let img = NSImage(contentsOf: url) {
                    return img
                }
            }
        }

        // 5. Development filesystem fallback
        let devPaths = [
            "/Users/saumya/MacDev/CustomVolumeHUD/Sources/CustomVolumeHUDLib/Resources/\(filename)",
            "/Users/saumya/MacDev/CustomVolumeHUD/Sources/CustomVolumeHUD/Resources/\(filename)",
            "./Sources/CustomVolumeHUDLib/Resources/\(filename)",
            "./Sources/CustomVolumeHUD/Resources/\(filename)"
        ]

        for path in devPaths {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                return img
            }
        }

        return nil
    }
}

/// An AppKit NSView that forces strict nearest-neighbor sampling and disables antialiasing.
public final class NearestNeighborImageView: NSView {
    public var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    public var isFlippedHorizontal: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    public init(image: NSImage? = nil, isFlippedHorizontal: Bool = false) {
        self.image = image
        self.isFlippedHorizontal = isFlippedHorizontal
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        if let scale = NSScreen.main?.backingScaleFactor {
            layer?.contentsScale = scale
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        if let scale = NSScreen.main?.backingScaleFactor {
            layer?.contentsScale = scale
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor {
            layer?.contentsScale = scale
        }
        needsDisplay = true
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        if let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor {
            layer?.contentsScale = scale
        }
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image = image, let context = NSGraphicsContext.current else { return }

        context.saveGraphicsState()
        context.imageInterpolation = .none
        context.shouldAntialias = false

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            context.restoreGraphicsState()
            return
        }

        // Maintain uniform square pixels with uniform scale
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        guard scale > 0 else {
            context.restoreGraphicsState()
            return
        }
        let drawWidth = round(imageSize.width * scale)
        let drawHeight = round(imageSize.height * scale)
        let drawX = round((bounds.width - drawWidth) / 2.0)
        let drawY: CGFloat = 0.0 // bottom-aligned sprite
        let targetRect = NSRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)

        if isFlippedHorizontal {
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.width, yBy: 0)
            transform.scaleX(by: -1.0, yBy: 1.0)
            transform.concat()
        }

        image.draw(
            in: targetRect,
            from: NSRect(origin: .zero, size: imageSize),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [
                .interpolation: NSImageInterpolation.none.rawValue
            ]
        )

        context.restoreGraphicsState()
    }
}

/// SwiftUI wrapper for NearestNeighborImageView to guarantee crisp pixel art rendering.
public struct PixelArtSpriteView: NSViewRepresentable {
    public let image: NSImage?
    public let isFlippedHorizontal: Bool

    public init(image: NSImage?, isFlippedHorizontal: Bool = false) {
        self.image = image
        self.isFlippedHorizontal = isFlippedHorizontal
    }

    public func makeNSView(context: Context) -> NearestNeighborImageView {
        let view = NearestNeighborImageView(image: image, isFlippedHorizontal: isFlippedHorizontal)
        return view
    }

    public func updateNSView(_ nsView: NearestNeighborImageView, context: Context) {
        nsView.image = image
        nsView.isFlippedHorizontal = isFlippedHorizontal
        nsView.needsDisplay = true
    }
}
