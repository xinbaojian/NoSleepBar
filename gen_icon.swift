import AppKit

// 生成 NoSleepBar 的 1024x1024 基础图标，再由 build.sh 通过 sips/iconutil 生成 .icns。
// 设计：圆角方形底 + 靛蓝渐变 + 白色太阳，呼应“保持唤醒/常亮”。

let canvasSize = 1024
let canvas = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
canvas.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("无法获取图形上下文")
}

// 背景圆角矩形（macOS 大圆角风格）
let inset: CGFloat = 72
let bgRect = CGRect(
    x: inset,
    y: inset,
    width: CGFloat(canvasSize) - inset * 2,
    height: CGFloat(canvasSize) - inset * 2
)
let corner: CGFloat = 224
let bgPath = CGPath(
    roundedRect: bgRect,
    cornerWidth: corner,
    cornerHeight: corner,
    transform: nil
)

// 靛蓝渐变（顶部亮，底部深）
let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [
    CGColor(red: 0.32, green: 0.48, blue: 0.98, alpha: 1.0),
    CGColor(red: 0.15, green: 0.20, blue: 0.62, alpha: 1.0)
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: 952),
        end: CGPoint(x: 512, y: 72),
        options: []
    )
    ctx.restoreGState()
}

// 太阳光芒：8 条圆头线段
let center = CGPoint(x: 512, y: 512)
ctx.saveGState()
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(46)
ctx.setLineCap(.round)
for i in 0..<8 {
    let angle = CGFloat(i) * .pi / 4
    let inner = CGPoint(
        x: center.x + cos(angle) * 178,
        y: center.y + sin(angle) * 178
    )
    let outer = CGPoint(
        x: center.x + cos(angle) * 282,
        y: center.y + sin(angle) * 282
    )
    ctx.move(to: inner)
    ctx.addLine(to: outer)
}
ctx.strokePath()
ctx.restoreGState()

// 太阳中心圆
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: 392, y: 392, width: 240, height: 240))

canvas.unlockFocus()

let outputURL = URL(fileURLWithPath: "/tmp/nosleepbar_icon_1024.png")
guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("生成 PNG 失败")
}
try png.write(to: outputURL)
print(outputURL.path)
