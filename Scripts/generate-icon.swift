import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Swift3270.iconset", isDirectory: true)
let icns = root.appendingPathComponent("Swift3270.icns")

try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.removeItem(at: icns)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

for (name, size) in sizes {
    guard let bitmap = NSBitmapImageRep(
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
    ) else {
        fatalError("Could not create bitmap for \(name)")
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create graphics context for \(name)")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let scale = CGFloat(size)
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: scale * 0.07, dy: scale * 0.07), xRadius: scale * 0.20, yRadius: scale * 0.20)
    color(0.035, 0.043, 0.060).setFill()
    bg.fill()

    let panel = NSBezierPath(roundedRect: rect.insetBy(dx: scale * 0.16, dy: scale * 0.21), xRadius: scale * 0.08, yRadius: scale * 0.08)
    color(0.08, 0.10, 0.14).setFill()
    panel.fill()
    color(0.20, 0.56, 1.00, 0.85).setStroke()
    panel.lineWidth = max(1, scale * 0.018)
    panel.stroke()

    let prompt = NSBezierPath()
    prompt.move(to: NSPoint(x: scale * 0.29, y: scale * 0.54))
    prompt.line(to: NSPoint(x: scale * 0.39, y: scale * 0.50))
    prompt.line(to: NSPoint(x: scale * 0.29, y: scale * 0.46))
    color(0.50, 0.95, 0.62).setStroke()
    prompt.lineWidth = max(2, scale * 0.045)
    prompt.lineCapStyle = .round
    prompt.lineJoinStyle = .round
    prompt.stroke()

    let cursor = NSBezierPath(roundedRect: NSRect(x: scale * 0.46, y: scale * 0.455, width: scale * 0.22, height: scale * 0.045), xRadius: scale * 0.02, yRadius: scale * 0.02)
    color(0.74, 0.90, 1.00).setFill()
    cursor.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(name)")
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let icnsEntries: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianUInt32(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return Data(bytes: &number, count: MemoryLayout<UInt32>.size)
}

func fourCharacterData(_ value: String) -> Data {
    guard let data = value.data(using: .ascii), data.count == 4 else {
        fatalError("Invalid ICNS type \(value)")
    }
    return data
}

var chunks = Data()
for entry in icnsEntries {
    let png = try Data(contentsOf: iconset.appendingPathComponent(entry.filename))
    chunks.append(fourCharacterData(entry.type))
    chunks.append(bigEndianUInt32(png.count + 8))
    chunks.append(png)
}

var icnsData = Data()
icnsData.append(fourCharacterData("icns"))
icnsData.append(bigEndianUInt32(chunks.count + 8))
icnsData.append(chunks)
try icnsData.write(to: icns)
