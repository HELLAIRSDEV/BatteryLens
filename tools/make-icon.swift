import Cocoa

// Генератор иконки приложения: рисует градиентный квадрат с батарейкой
// и сохраняет набор PNG, из которого iconutil собирает .icns.
//
// Запуск:
//   swift tools/make-icon.swift Resources/AppIcon.iconset

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let baseSize = 1024

func makeImage() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: baseSize,
        pixelsHigh: baseSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = CGRect(x: 60, y: 60, width: 904, height: 904)
    let path = CGPath(roundedRect: rect, cornerWidth: 200, cornerHeight: 200, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        NSColor(srgbRed: 0.16, green: 0.78, blue: 0.42, alpha: 1).cgColor,
        NSColor(srgbRed: 0.05, green: 0.55, blue: 0.90, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
    ctx.restoreGState()

    // Батарейка
    let bodyWidth: CGFloat = 520
    let bodyHeight: CGFloat = 280
    let bodyX = (CGFloat(baseSize) - bodyWidth - 40) / 2
    let bodyY = (CGFloat(baseSize) - bodyHeight) / 2
    let body = CGRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 48, cornerHeight: 48, transform: nil)

    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(32)
    ctx.addPath(bodyPath)
    ctx.strokePath()

    // Контакт
    let cap = CGRect(x: body.maxX + 22, y: body.midY - 55, width: 34, height: 110)
    ctx.addPath(CGPath(roundedRect: cap, cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.fillPath()

    // Заполнение 70%
    let inset: CGFloat = 40
    let fillWidth = (bodyWidth - inset * 2) * 0.7
    let fill = CGRect(x: body.minX + inset, y: body.minY + inset, width: fillWidth, height: bodyHeight - inset * 2)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(CGPath(roundedRect: fill, cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("не удалось закодировать PNG")
    }
    try! png.write(to: URL(fileURLWithPath: "\(outputDir)/\(name)"))
}

let fm = FileManager.default
try? fm.removeItem(atPath: outputDir)
try! fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let master = makeImage()

// Обязательный набор для iconutil
let variants: [(String, Int)] = [
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

for (name, size) in variants {
    let resized = NSBitmapImageRep(
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
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resized)
    master.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    save(resized, name)
}

print("иконки сохранены в \(outputDir)")
