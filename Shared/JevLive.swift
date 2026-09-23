import Foundation
import Vision
import CoreVideo

// MARK: - 直播模式（实验分支）：录屏 → 本地 OCR → 解析对话 → 免复制出候选
//
// 数据流：广播扩展（JevLive）每 2 秒取一帧 → Vision 本地识别文字 → LiveChatParser
// 按「气泡横向位置」分出我方/对方 → 快照写 App Group → 键盘与主 App 轮询读取，
// 把「对方最新一条 + 前文」交给现有 JevPipeline。整条链路里没有新依赖，
// 生成层、话术、判断层全部复用旧管线——输入从「剪贴板」换成了「屏幕」。

/// 一行识别出来的对话。side 靠气泡的横向位置判断（右半屏 = 我方），
/// 这是启发式：微信/QQ/iMessage 等主流 App 都满足，但换行气泡、贴图、引用块会识别错。
struct LiveLine: Codable, Equatable {
    enum Side: String, Codable {
        case them, me, system
    }

    var side: Side
    var text: String
}

/// 一次识别的完整快照。存 App Group UserDefaults，跨进程共享：
/// 广播扩展写，键盘与主 App 读。画面没变化时不重写，所以 updatedAt 兼任「画面最后一次变动」
/// 的时间戳，主 App 用它做防抖（对方连发时不急着分析最后一条）。
struct LiveSnapshot: Codable, Equatable {
    var updatedAt: Date
    var lines: [LiveLine]
    /// 扩展自启动以来见过的帧数（诊断用，够判断「广播活着但没有新帧」）
    var frameCount: Int

    /// 当前该回的消息：跳过尾部的系统行（时间/撤回提示），从尾往前取连续的对方气泡。
    /// 多行气泡合并成一条；没有对方消息（比如最后一屏全是自己发的）返回 nil。
    var latestIncoming: String? {
        var i = lines.count - 1
        while i >= 0, lines[i].side == .system { i -= 1 }
        guard i >= 0, lines[i].side == .them else { return nil }
        var buf: [String] = []
        while i >= 0, lines[i].side == .them {
            buf.insert(lines[i].text, at: 0)
            i -= 1
        }
        let joined = buf.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }

    /// 前文（给管线的 context）：latestIncoming 之前的对话，带说话人前缀，
    /// 只取最近 14 行 / 600 字——上下文是给起草模型定语气的，太长白花 token。
    var contextText: String? {
        var i = lines.count - 1
        while i >= 0, lines[i].side == .system { i -= 1 }
        guard i >= 0, lines[i].side == .them else { return nil }
        var buf: [String] = []
        var j = i - 1
        while j >= 0, buf.count < 14 {
            let line = lines[j]
            switch line.side {
            case .them: buf.insert("对方：" + line.text, at: 0)
            case .me: buf.insert("我：" + line.text, at: 0)
            case .system: break
            }
            j -= 1
        }
        let joined = buf.joined(separator: "\n").suffix(600)
        return joined.isEmpty ? nil : String(joined)
    }
}

// MARK: - 对话解析（纯函数，App 的自检页可以直接喂截图验证）

enum LiveChatParser {

    /// Vision 的输出：文本 + 归一化包围盒（原点左下）。抽成值类型方便测试与自检页复用。
    struct Observation {
        var text: String
        var boundingBox: CGRect
    }

    /// 聊天界面的固定 UI 文案，识别出来也没信息量。
    private static let uiTokens: Set<String> = [
        "发送", "输入", "按住说话", "按住 说话", "语音", "相册", "红包", "转账",
        "返回", "微信", "正在输入", "对方正在输入...", "已读", "已送达", "哇", "拍一拍",
    ]
    private static let timePattern = try! NSRegularExpression(pattern: #"^([0-9]{1,2}[:：][0-9]{2}|昨天|今天|星期[一二三四五六日天]|昨天\s*[0-9]{1,2}[:：][0-9]{2})$"#)

    /// 观测 → 对话行。步骤：清洗 → 按 midY 聚成视觉行 → 行内按 x 拼接 → 并集框中点定左右。
    static func parse(_ observations: [Observation]) -> [LiveLine] {
        let cleaned: [Observation] = observations.compactMap { o in
            let t = o.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            if uiTokens.contains(t) { return nil }
            if timePattern.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil { return nil }
            return Observation(text: t, boundingBox: o.boundingBox)
        }
        guard !cleaned.isEmpty else { return [] }

        // Vision 的 y 轴向上（原点左下）：从上往下扫，midY 接近的算同一视觉行。
        // 0.55 × 行高是经验值：同一行内多框（中文一段常碎成几框）的 midY 几乎重合，
        // 相邻两行气泡的高度差远大于半个行高。
        let sorted = cleaned.sorted { a, b in
            let am = a.boundingBox.midY, bm = b.boundingBox.midY
            return am == bm ? a.boundingBox.midX < b.boundingBox.midX : am > bm
        }
        var rows: [[Observation]] = []
        for o in sorted {
            if var last = rows.last, let first = last.first {
                let tol = 0.55 * max(first.boundingBox.height, o.boundingBox.height, 0.02)
                if abs(first.boundingBox.midY - o.boundingBox.midY) < tol {
                    last.append(o)
                    rows[rows.count - 1] = last
                    continue
                }
            }
            rows.append([o])
        }

        var lines: [LiveLine] = []
        for row in rows {
            let items = row.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
            var text = ""
            for item in items {
                if let last = text.last, joinsTight(last, item.text.first ?? " ") {
                    text += item.text
                } else {
                    if !text.isEmpty { text += " " }
                    text += item.text
                }
            }
            // 并集框中点：短气泡贴边（微信里「哦」在对方手里 midX≈0.15，在我方手里 midX≈0.9），
            // 长气泡趋中。0.55 偏向我方一点，因为长消息里我方气泡整体更靠右。
            let union = items.dropFirst().reduce(items[0].boundingBox) { $0.union($1.boundingBox) }
            let side: LiveLine.Side = union.midX > 0.55 ? .me : .them
            lines.append(LiveLine(side: side, text: text))
        }
        return lines
    }

    /// 行内多框拼接：两边都是 CJK 就贴死（OCR 常把一句中文切成几框，加空格反而碍事），
    /// 否则补空格保住英文词距。
    private static func joinsTight(_ left: Character, _ right: Character) -> Bool {
        func cjk(_ c: Character) -> Bool {
            guard let s = String(c).unicodeScalars.first else { return false }
            return (0x4E00...0x9FFF).contains(s.value) || (0x3000...0x303F).contains(s.value)
                || (0xFF00...0xFFEF).contains(s.value)
        }
        return cjk(left) && cjk(right)
    }
}

// MARK: - App Group 存储

/// 快照的唯一存放点。不放新文件进容器目录——UserDefaults 跨进程同步由 cfprefsd 负责，
/// 键盘 2 秒轮询一次小 key 的开销可以忽略。
enum JevLiveStore {
    static let snapshotKey = "jev.live.snapshot.v1"
    /// 与 JevStore.appGroupID 同值。JevLive.swift 单文件编译进广播扩展（不带 JevModel），
    /// 所以这里自带一份——改 App Group 时 entitlements / project.yml / 这两处要一起改。
    private static let appGroupID = "group.com.jevchat.jarvis.ios"
    /// 快照多久之内算「监听中」。广播一停扩展就没了，快照自然过期，
    /// 键盘/主 App 据此回到空闲，不需要显式的停止信号。
    static let freshWindow: TimeInterval = 150

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func save(_ snapshot: LiveSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> LiveSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey),
              let snap = try? JSONDecoder().decode(LiveSnapshot.self, from: data) else { return nil }
        return snap
    }

    static func isFresh(_ snapshot: LiveSnapshot) -> Bool {
        Date().timeIntervalSince(snapshot.updatedAt) < freshWindow
    }

    /// 「监听中且能 actionable」= 快照新鲜 + 里面有一条待回的对方消息。
    /// 键盘待机页用这一个布尔决定要不要显示「读屏幕分析」按钮。
    static var isActionable: Bool {
        guard let snap = load(), isFresh(snap), snap.latestIncoming != nil else { return false }
        return true
    }
}

// MARK: - OCR 引擎（广播扩展与自检页共用的同一条识别路径）

enum LiveOCREngine {

    /// 只识别聊天区：裁掉顶部状态栏 (~5%) 与底部输入条 (~14%)（Vision 原点左下）。
    /// 少一半图面 = 少一半识别耗时，也避免把「发送」按钮认成对话。
    /// 注意：设了 regionOfInterest 后，结果的 boundingBox 是相对该区域的归一化坐标——
    /// 我们只用 midX 定左右、midY 排序，两种坐标系下结论一致。
    static let regionOfInterest = CGRect(x: 0, y: 0.14, width: 1, height: 0.81)

    static func recognize(pixelBuffer: CVPixelBuffer) -> [LiveLine] {
        var lines: [LiveLine] = []
        // 广播扩展内存上限 ~50MB（jetsam 硬杀）：识别全程包在 autoreleasepool 里，
        // 帧用完即还；识别档位与耗时见 makeRequest() 里的说明。
        autoreleasepool {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            let request = makeRequest()
            try? handler.perform([request])
            lines = finish(request)
        }
        return lines
    }

    /// 自检页用：静态图（截图/合成示例）走同一条解析路径。
    static func recognize(cgImage: CGImage) -> [LiveLine] {
        var lines: [LiveLine] = []
        autoreleasepool {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            let request = makeRequest()
            try? handler.perform([request])
            lines = finish(request)
        }
        return lines
    }

    private static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        // 档位必须是 accurate：冒烟实测（macOS 同源 Vision）fast 档对中文几乎全瞎
        //（5 条气泡只认出 1 个英文词），accurate 档全对。代价是单帧更慢更吃内存，
        // 靠 2 秒节流摊平；万一真机上 50MB 上限杀进程，把这里改回 .fast 再议。
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.minimumTextHeight = 0.015
        request.regionOfInterest = regionOfInterest
        return request
    }

    private static func finish(_ request: VNRecognizeTextRequest) -> [LiveLine] {
        let observations = (request.results ?? []).compactMap { o -> LiveChatParser.Observation? in
            guard let text = o.topCandidates(1).first?.string else { return nil }
            return LiveChatParser.Observation(text: text, boundingBox: o.boundingBox)
        }
        return LiveChatParser.parse(observations)
    }
}
