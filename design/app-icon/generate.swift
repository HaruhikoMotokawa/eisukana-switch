#!/usr/bin/env swift
// アプリアイコンの元データ。CoreGraphics で描いて PNG を書き出す（#19）。
//
//   swift design/app-icon/generate.swift
//
// で、1024px の原画（design/app-icon/AppIcon-1024.png）と、AppIcon.appiconset の 10 サイズを
// 上書きする。各サイズは縮小ではなくそのピクセル数で描き直すので、小さいサイズでも線がにじまない。
//
// デザイン: 2 つの ⌘ キーを並べ、左に「A」（英数）、右に「あ」（かな）を載せる。
// 64px 以下では ⌘ を省き、文字を大きくした簡易版を使う。

import AppKit
import CoreText

// MARK: - レイアウト（1024 x 1024 の座標系。原点は左下）

/// Apple の macOS アイコンテンプレートに合わせ、本体は 824 x 824 を中央に置く。
/// 周りの余白は影のためのスペース。
let canvas: CGFloat = 1024
let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyCornerRadius: CGFloat = 185.4

struct Palette {
    static let backgroundTop = CGColor(srgbRed: 0.40, green: 0.47, blue: 1.00, alpha: 1)
    static let backgroundBottom = CGColor(srgbRed: 0.20, green: 0.25, blue: 0.80, alpha: 1)
    static let keyFaceTop = CGColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1)
    static let keyFaceBottom = CGColor(srgbRed: 0.91, green: 0.92, blue: 0.96, alpha: 1)
    static let keySide = CGColor(srgbRed: 0.66, green: 0.69, blue: 0.82, alpha: 1)
    static let keyShadow = CGColor(srgbRed: 0.05, green: 0.07, blue: 0.30, alpha: 0.35)
    static let glyph = CGColor(srgbRed: 0.14, green: 0.16, blue: 0.29, alpha: 1)
    static let commandMark = CGColor(srgbRed: 0.47, green: 0.50, blue: 0.62, alpha: 1)
    static let iconShadow = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.30)
}

struct KeyCap {
    let rect: CGRect
    let label: String
    let font: CTFont
}

// MARK: - 描画

/// 角が連続的に曲がる（スクワークル）角丸矩形。macOS のアイコン形状に近づける。
func continuousRoundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    // 角の曲線を円弧より長い区間（r * k）に広げ、制御点を辺の延長線上に置いて曲率が 0 から立ち上がるようにする。
    // 制御点の位置 c は、曲線の中点が半径 r の円弧の中点と重なるように決めている。
    let r = min(radius, min(rect.width, rect.height) / 2)
    let k: CGFloat = 1.528665  // 曲線の始点を角から r * k の位置に取る
    let c: CGFloat = 0.822     // 制御点を始点から角へ向かって e * c の位置に取る
    let e = min(r * k, min(rect.width, rect.height) / 2)
    let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)

    path.move(to: CGPoint(x: minX + e, y: maxY))
    path.addLine(to: CGPoint(x: maxX - e, y: maxY))
    path.addCurve(to: CGPoint(x: maxX, y: maxY - e),
                  control1: CGPoint(x: maxX - e * (1 - c), y: maxY),
                  control2: CGPoint(x: maxX, y: maxY - e * (1 - c)))
    path.addLine(to: CGPoint(x: maxX, y: minY + e))
    path.addCurve(to: CGPoint(x: maxX - e, y: minY),
                  control1: CGPoint(x: maxX, y: minY + e * (1 - c)),
                  control2: CGPoint(x: maxX - e * (1 - c), y: minY))
    path.addLine(to: CGPoint(x: minX + e, y: minY))
    path.addCurve(to: CGPoint(x: minX, y: minY + e),
                  control1: CGPoint(x: minX + e * (1 - c), y: minY),
                  control2: CGPoint(x: minX, y: minY + e * (1 - c)))
    path.addLine(to: CGPoint(x: minX, y: maxY - e))
    path.addCurve(to: CGPoint(x: minX + e, y: maxY),
                  control1: CGPoint(x: minX, y: maxY - e * (1 - c)),
                  control2: CGPoint(x: minX + e * (1 - c), y: maxY))
    path.closeSubpath()
    return path
}

func fillLinearGradient(_ context: CGContext, path: CGPath, top: CGColor, bottom: CGColor) {
    let rect = path.boundingBox
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [top, bottom] as CFArray,
                              locations: [0, 1])!
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: rect.maxY),
                               end: CGPoint(x: rect.midX, y: rect.minY),
                               options: [])
    context.restoreGState()
}

/// グリフの実際の輪郭で中央揃えにして文字を描く。行の高さで揃えると「A」と「あ」の位置がずれるため。
func drawText(_ context: CGContext, _ text: String, font: CTFont, color: CGColor, center: CGPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.saveGState()
    context.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, context)
    context.restoreGState()
}

/// システムフォント（SF Pro）。追加インストールしなくても、どの Mac でも同じ字形になる。
func systemFont(size: CGFloat, weight: NSFont.Weight) -> CTFont {
    NSFont.systemFont(ofSize: size, weight: weight) as CTFont
}

/// 名前で指定するフォント。macOS に標準で入っているものだけを使う。
func font(_ name: String, size: CGFloat) -> CTFont {
    let font = CTFontCreateWithName(name as CFString, size, nil)
    // 指定したフォントが無いとシステムが別のフォントで代用するので、気づけるように止める。
    precondition(CTFontCopyPostScriptName(font) as String == name, "フォント \(name) が見つかりません")
    return font
}

func drawIcon(_ context: CGContext, simplified: Bool) {
    // 本体（影 → グラデーション）
    let body = continuousRoundedRect(bodyRect, radius: bodyCornerRadius)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: Palette.iconShadow)
    context.addPath(body)
    context.setFillColor(Palette.backgroundBottom)
    context.fillPath()
    context.restoreGState()
    fillLinearGradient(context, path: body, top: Palette.backgroundTop, bottom: Palette.backgroundBottom)

    // キー 2 つ。簡易版は余白を詰めてキーを大きくする。
    let keyWidth: CGFloat = simplified ? 350 : 320
    let keyHeight: CGFloat = simplified ? 440 : 400
    let gap: CGFloat = simplified ? 44 : 64
    let originX = bodyRect.midX - keyWidth - gap / 2
    let originY = bodyRect.midY - keyHeight / 2 + 14  // 側面の厚みぶん少し上げて見た目の中心を合わせる
    let labelSize: CGFloat = simplified ? 300 : 200
    let keys = [
        KeyCap(rect: CGRect(x: originX, y: originY, width: keyWidth, height: keyHeight),
               label: "A", font: systemFont(size: labelSize, weight: .bold)),
        KeyCap(rect: CGRect(x: originX + keyWidth + gap, y: originY, width: keyWidth, height: keyHeight),
               label: "あ", font: font("HiraginoSans-W7", size: labelSize * 0.95)),
    ]
    let commandFont = systemFont(size: 96, weight: .semibold)
    let keyRadius: CGFloat = simplified ? 70 : 60
    let sideDepth: CGFloat = simplified ? 28 : 22

    for key in keys {
        // 影と側面（キーの厚み）
        let side = continuousRoundedRect(key.rect.offsetBy(dx: 0, dy: -sideDepth), radius: keyRadius)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: Palette.keyShadow)
        context.addPath(side)
        context.setFillColor(Palette.keySide)
        context.fillPath()
        context.restoreGState()

        // 天面
        let face = continuousRoundedRect(key.rect, radius: keyRadius)
        fillLinearGradient(context, path: face, top: Palette.keyFaceTop, bottom: Palette.keyFaceBottom)

        if simplified {
            drawText(context, key.label, font: key.font, color: Palette.glyph,
                     center: CGPoint(x: key.rect.midX, y: key.rect.midY))
        } else {
            drawText(context, "⌘", font: commandFont, color: Palette.commandMark,
                     center: CGPoint(x: key.rect.midX, y: key.rect.maxY - 100))
            drawText(context, key.label, font: key.font, color: Palette.glyph,
                     center: CGPoint(x: key.rect.midX, y: key.rect.minY + 150))
        }
    }
}

// MARK: - 書き出し

func renderPNG(pixels: Int, simplified: Bool, to url: URL) throws {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / canvas
    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high
    context.setShouldSmoothFonts(false)
    drawIcon(context, simplified: simplified)

    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "generate", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(url.path) を書き出せません"])
    }
}

let scriptDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repositoryRoot = scriptDirectory.deletingLastPathComponent().deletingLastPathComponent()
let appIconSet = repositoryRoot.appendingPathComponent("EisuKanaSwitch/Assets.xcassets/AppIcon.appiconset")

/// 64px 以下は ⌘ が潰れて読めないので簡易版にする。
let simplifiedMaxPixels = 64

try renderPNG(pixels: 1024, simplified: false, to: scriptDirectory.appendingPathComponent("AppIcon-1024.png"))

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try renderPNG(pixels: pixels, simplified: pixels <= simplifiedMaxPixels,
                      to: appIconSet.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: appIconSet.appendingPathComponent("Contents.json"))
print("書き出しました: \(appIconSet.path)")
