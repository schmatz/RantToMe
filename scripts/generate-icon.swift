#!/usr/bin/env swift

import AppKit
import Foundation

// Icon sizes to generate
let iconSizes: [(filename: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

// Output directory
let scriptPath = URL(fileURLWithPath: #file)
let projectRoot = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
let outputDir = projectRoot.appendingPathComponent("RantToMe/Assets.xcassets/AppIcon.appiconset")

func createIcon(size: Int) -> NSBitmapImageRep {
    // Create bitmap with explicit pixel dimensions (bypasses Retina scaling)
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    // Set size to match pixels (1:1 scale, not Retina)
    bitmapRep.size = NSSize(width: size, height: size)

    // Create graphics context from bitmap
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    // Draw gradient background
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22 // macOS-style rounded corners
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Create gradient (purple to blue)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.4, green: 0.2, blue: 0.8, alpha: 1.0), // Purple
        NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.9, alpha: 1.0), // Blue
    ])!

    gradient.draw(in: path, angle: -45)

    // Draw SF Symbol "waveform"
    let symbolSize = CGFloat(size) * 0.55
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)

    if let symbolImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {

        // Create a tinted version of the symbol
        let tintedSymbol = NSImage(size: symbolImage.size)
        tintedSymbol.lockFocus()
        NSColor.white.set()
        let symbolRect = NSRect(origin: .zero, size: symbolImage.size)
        symbolImage.draw(in: symbolRect)
        symbolRect.fill(using: .sourceAtop)
        tintedSymbol.unlockFocus()

        // Center the symbol in the icon
        let symbolDrawSize = tintedSymbol.size
        let x = (CGFloat(size) - symbolDrawSize.width) / 2
        let y = (CGFloat(size) - symbolDrawSize.height) / 2

        tintedSymbol.draw(
            in: NSRect(x: x, y: y, width: symbolDrawSize.width, height: symbolDrawSize.height),
            from: NSRect(origin: .zero, size: symbolDrawSize),
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    NSGraphicsContext.restoreGraphicsState()

    return bitmapRep
}

func savePNG(bitmapRep: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }

    try pngData.write(to: url)
}

// Main execution
print("Generating app icons...")
print("Output directory: \(outputDir.path)")

for (filename, size) in iconSizes {
    let icon = createIcon(size: size)
    let outputPath = outputDir.appendingPathComponent(filename)

    do {
        try savePNG(bitmapRep: icon, to: outputPath)
        print("✓ Generated \(filename) (\(size)x\(size))")
    } catch {
        print("✗ Failed to generate \(filename): \(error.localizedDescription)")
        exit(1)
    }
}

print("\nAll icons generated successfully!")
