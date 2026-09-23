// 直播模式 OCR 链路的独立冒烟测试：同一份 Shared/JevLive.swift，
// 在 macOS 上用 CoreGraphics 画一张假聊天图 → LiveOCREngine.recognize → 断言解析结果。
// 用法：cp 本文件到仓库根目录命名 main.swift，swiftc -O Shared/JevLive.swift main.swift -o /tmp/t && /tmp/t

import Foundation
import CoreText
import CoreGraphics
import AppKit
import ImageIO
import UniformTypeIdentifiers
import Vision

let W = 780.0, H = 1280.0

func drawText(_ s: String, size: CGFloat, color: CGColor, at point: CGPoint, in ctx: CGContext) {
    let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, size, nil)
    let attr = NSAttributedString(string: s, attributes: [
        .font: font, .foregroundColor: color,
    ])
    let line = CTLineCreateWithAttributedString(attr)
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

func bubble(_ text: String, them: Bool, y: CGFloat, in ctx: CGContext) {
    let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, 30, nil)
    let attr = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
    ])
    let line = CTLineCreateWithAttributedString(attr)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    let rect = them
        ? CGRect(x: 120, y: y, width: width + 48, height: 64)
        : CGRect(x: W - 120 - width - 48, y: y, width: width + 48, height: 64)
    let color: CGColor = them
        ? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        : CGColor(red: 0.58, green: 0.86, blue: 0.44, alpha: 1)
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.fillPath()
    drawText(text, size: 30, color: CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
             at: CGPoint(x: rect.minX + 24, y: rect.minY + 16), in: ctx)
}

let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// 标准 CG 坐标（原点左下，y 向上）。CGBitmapContext 的首行在内存里是图顶部，makeImage 直接可用。
ctx.setFillColor(CGColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
drawText("20:31", size: 24, color: CGColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
         at: CGPoint(x: 350, y: 1200), in: ctx)
bubble("在吗，周末的那个方案你看了一眼没", them: true, y: 1080, in: ctx)
bubble("看了看了，这两天有点忙", them: false, y: 980, in: ctx)
bubble("周五之前给你一版完整的", them: false, y: 880, in: ctx)
bubble("行，记得把报价也放进去，老板要看价格", them: true, y: 780, in: ctx)
bubble("好嘞", them: false, y: 680, in: ctx)
bubble("对了上次说的那家餐厅周末去吗", them: true, y: 580, in: ctx)
drawText("发送", size: 28, color: CGColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1),
         at: CGPoint(x: 350, y: 60), in: ctx)

let image = ctx.makeImage()!

let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/tmp/live_test.png") as CFURL,
                                           UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("已导出 /tmp/live_test.png")

// 两种识别档位对比：时间与中文识别质量
func run(_ level: VNRequestTextRecognitionLevel) -> ([LiveLine], Double) {
    let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = level
    req.usesLanguageCorrection = false
    req.recognitionLanguages = ["zh-Hans", "en-US"]
    req.minimumTextHeight = 0.015
    req.regionOfInterest = LiveOCREngine.regionOfInterest
    let t0 = Date()
    try? handler.perform([req])
    let dt = Date().timeIntervalSince(t0)
    let obs = (req.results ?? []).compactMap { o -> LiveChatParser.Observation? in
        guard let text = o.topCandidates(1).first?.string else { return nil }
        return LiveChatParser.Observation(text: text, boundingBox: o.boundingBox)
    }
    return (LiveChatParser.parse(obs), dt)
}

print("—— .fast ——")
let (fastLines, fastDt) = run(.fast)
for l in fastLines { let s = l.side == .them ? "[对方]" : l.side == .me ? "[我]　" : "[系统]"; print("\(s) \(l.text)") }
print(String(format: "耗时 %.0f ms", fastDt * 1000))

print("—— .accurate ——")
let (accLines, accDt) = run(.accurate)
for l in accLines { let s = l.side == .them ? "[对方]" : l.side == .me ? "[我]　" : "[系统]"; print("\(s) \(l.text)") }
print(String(format: "耗时 %.0f ms", accDt * 1000))

let lines = LiveOCREngine.recognize(cgImage: image)
print("—— 引擎全链路（accurate）——")
for l in lines { let s = l.side == .them ? "[对方]" : l.side == .me ? "[我]　" : "[系统]"; print("\(s) \(l.text)") }

var failures = 0
func check(_ cond: Bool, _ name: String) {
    print((cond ? "✅ " : "❌ ") + name)
    if !cond { failures += 1 }
}

check(!lines.isEmpty, "识别出非空对话行")
check(!lines.contains { $0.side == .system }, "时间戳/底部 UI 被清洗掉")
check(lines.first?.side == .them, "第一行归属对方（左）")
let lastMe = lines.filter { $0.side == .me }.last
check(lastMe?.text.contains("好嘞") == true, "最后一条我方消息为「好嘞」")
check(lines.last?.side == .them, "末尾是对方消息")
check(lines.last?.text.contains("餐厅") == true, "末行文本含「餐厅」，实际：\(lines.last?.text ?? "nil")")

if !lines.isEmpty {
    let snap = LiveSnapshot(updatedAt: Date(), lines: lines, frameCount: 1)
    check(snap.latestIncoming?.contains("餐厅") == true,
          "latestIncoming = 末条对方消息（含「餐厅」），实际：\(snap.latestIncoming ?? "nil")")
    let ctxText = snap.contextText ?? ""
    check(ctxText.contains("我："), "contextText 带说话人前缀")
    check(ctxText.contains("报价"), "contextText 含此前对话（报价那条）")
    check(!ctxText.contains("餐厅"), "contextText 不含待回消息本体")
}

print(failures == 0 ? "\n全部通过" : "\n有 \(failures) 项失败")
exit(failures == 0 ? 0 : 1)
