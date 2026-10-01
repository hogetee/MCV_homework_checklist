import AppKit
import DSStore

// This build tool writes installer artwork and Finder metadata. It never changes security settings.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Usage: InstallerLayout MOUNT_PATH preview|distribution")
}
let folder = URL(fileURLWithPath: arguments[1], isDirectory: true)
let preview = arguments[2] == "preview"
let width: CGFloat = 720
let height: CGFloat = 480
let background = folder.appendingPathComponent(".background.png")
let shortcut = folder.appendingPathComponent("เปิดตั้งค่า.inetloc")

@MainActor
func text(_ value: String, x: CGFloat = 40, y: CGFloat, width: CGFloat = 640,
          size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (value as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size * 2), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

@MainActor
func artwork() throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1440, pixelsHigh: 960,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let bitmapContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "InstallerLayout", code: 1)
    }
    bitmap.size = NSSize(width: width, height: height)
    let cg = bitmapContext.cgContext
    cg.scaleBy(x: 2, y: 2)
    cg.translateBy(x: 0, y: height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    defer { NSGraphicsContext.restoreGraphicsState() }
    let ink = NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.31, alpha: 1)
    let muted = NSColor(calibratedRed: 0.32, green: 0.40, blue: 0.52, alpha: 1)
    let blue = NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.86, alpha: 1)
    NSGradient(starting: NSColor(calibratedRed: 0.91, green: 0.96, blue: 1, alpha: 1),
        ending: NSColor(calibratedRed: 0.98, green: 0.99, blue: 1, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)
    text("ติดตั้ง MCVNot", y: 28, size: 30, weight: .bold, color: ink)
    text("ลากแอปไปที่ Applications", y: 76, size: 19, color: muted)
    for x: CGFloat in [112, 512] {
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 128, width: 96, height: 126),
                     xRadius: 24, yRadius: 24).fill()
    }
    blue.withAlphaComponent(0.7).setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 278, y: 192))
    arrow.line(to: NSPoint(x: 442, y: 192))
    arrow.move(to: NSPoint(x: 426, y: 176))
    arrow.line(to: NSPoint(x: 442, y: 192))
    arrow.line(to: NSPoint(x: 426, y: 208))
    arrow.stroke()
    text("เมื่อลากเสร็จ ให้เปิดแอปจาก Applications", y: 279, size: 15, color: muted)
    NSColor.white.withAlphaComponent(0.8).setFill()
    NSBezierPath(roundedRect: NSRect(x: 34, y: 325, width: 652, height: 145),
                 xRadius: 22, yRadius: 22).fill()
    text("คู่มือเริ่มใช้", x: 64, y: 337, width: 220, size: 15, weight: .semibold, color: ink)
    text(preview ? "macOS บล็อกแอป?" : "การตั้งค่า Mac", x: 436, y: 337, width: 220,
         size: 15, weight: .semibold, color: ink)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "InstallerLayout", code: 2)
    }
    try png.write(to: background)
}

try artwork()
let location = ["URL": "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"]
let locationData = try PropertyListSerialization.data(fromPropertyList: location, format: .xml, options: 0)
try locationData.write(to: shortcut)
var shortcutURL = shortcut
var values = URLResourceValues()
values.hasHiddenExtension = true
try shortcutURL.setResourceValues(values)
let settingsIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/System Settings.app")
guard NSWorkspace.shared.setIcon(settingsIcon, forFile: shortcut.path, options: []) else {
    throw NSError(domain: "InstallerLayout", code: 3)
}

var store = DSStore()
try store.setWindowBounds(top: 100, left: 160, bottom: 642, right: 880)
store.setWindowSettings(.init(windowBounds: "{{160, 100}, {720, 542}}", sidebarWidth: 0,
    containerShowSidebar: false, showSidebar: false, showTabView: false, showToolbar: false,
    showStatusBar: false, showPathBar: false, viewStyle: "icnv"))
store.setViewStyle(DSStore.ViewStyle.icon)
store.setIconViewSettings(.init(showIconPreview: false, showItemInfo: false, labelOnBottom: true,
    scrollPositionX: 0, scrollPositionY: 0, textSize: 13, iconSize: 80, gridSpacing: 100,
    viewOptionsVersion: 1, arrangeBy: "none"))
try store.setBackgroundPicture(imageURL: background, relativeTo: folder)
try store.setIconPositions([
    "MCVNot.app": (x: 160, y: 192),
    "Applications": (x: 560, y: 192),
    "เริ่มใช้.txt": (x: 174, y: 400),
    "เปิดตั้งค่า.inetloc": (x: 546, y: 400)
])
try store.write(to: folder.appendingPathComponent(".DS_Store"))
let saved = try DSStore.read(from: folder.appendingPathComponent(".DS_Store"))
guard saved.iconViewSettings()?.backgroundType == 2,
      saved.iconPosition(for: "Applications")?.x == 560 else {
    throw NSError(domain: "InstallerLayout", code: 4)
}
print("Wrote installer background, settings shortcut, and Finder layout.")
