import SwiftUI
import ReplayKit
import PhotosUI
import UIKit

// MARK: - 直播模式（实验分支）
//
// 与剪贴板路径的差别只在「输入」：不再长按复制，而是广播扩展持续录屏 + 本地 OCR，
// 把「对方最新一条 + 前文」自动喂给同一条 JevPipeline。
// 本页职责：① 放系统的广播开始按钮；② 实时展示识别结果；③ 前台时自动分析；
// ④ 自检（合成/相册截图走同一条 OCR 路径，不开广播也能验证识别质量）。

struct LiveView: View {
    @EnvironmentObject private var store: ConfigStore

    @State private var snapshot: LiveSnapshot?
    @State private var autoAnalyze = true
    @State private var analysis: Analysis?
    @State private var analyzing = false
    @State private var lastAnalyzed = ""
    @State private var notice: String?

    // 自检
    @State private var debugLines: [LiveLine] = []
    @State private var debugImage: UIImage?
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            Form {
                listenSection
                if let snap = snapshot, JevLiveStore.isFresh(snap) {
                    conversationSection(snap)
                }
                suggestSection
                selfTestSection
            }
            .navigationTitle("直播")
            .navigationViewStyle(.stack)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                tick()
            }
        }
    }

    // MARK: 监听

    private var listenSection: some View {
        Section {
            HStack {
                Image(systemName: JevLiveStore.isActionable ? "dot.radiowaves.left.and.right" : "circle.dashed")
                    .foregroundColor(isLive ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLive ? "监听中" : "未在监听").font(.callout.weight(.semibold))
                    if let snap = snapshot {
                        Text("最后识别到变化：\(snap.updatedAt.formatted(date: .omitted, time: .standard)) · \(snap.frameCount) 帧")
                            .font(.caption2).foregroundColor(.secondary)
                    } else {
                        Text("点下面按钮 → 选「秒回直播」→ 开始广播").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            BroadcastPickerView()
                .frame(height: 44)
                .frame(maxWidth: .infinity)
            Text("开始后切到任意聊天 App，这里会持续识别屏幕上的对话（每 2 秒一次，纯本地 OCR，只有拿去生成回复的对话文本会发给你自己配的模型）。状态栏会出现系统的紫色录屏指示，停止就在控制中心或回到这里点按钮。")
                .font(.caption).foregroundColor(.secondary)
        } header: {
            Text("屏幕监听")
        }
    }

    private var isLive: Bool {
        guard let snap = snapshot else { return false }
        return JevLiveStore.isFresh(snap)
    }

    // MARK: 实时对话

    private func conversationSection(_ snap: LiveSnapshot) -> some View {
        Section {
            ForEach(Array(snap.lines.suffix(8).enumerated()), id: \.offset) { _, line in
                HStack {
                    if line.side == .me { Spacer(minLength: 40) }
                    Text(line.text)
                        .font(.callout)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(bubbleColor(line.side))
                        .foregroundColor(line.side == .system ? .secondary : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    if line.side != .me { Spacer(minLength: 40) }
                }
            }
            if let latest = snap.latestIncoming {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill").font(.caption).foregroundColor(.accentColor)
                    Text("待回：\(latest)").font(.callout.weight(.medium)).lineLimit(3)
                }
            }
        } header: {
            Text("识别结果")
        }
    }

    private func bubbleColor(_ side: LiveLine.Side) -> Color {
        switch side {
        case .me: return Color.accentColor.opacity(0.15)
        case .them: return Color(.secondarySystemBackground)
        case .system: return .clear
        }
    }

    // MARK: 建议

    private var suggestSection: some View {
        Section {
            Toggle("对方有新消息时自动分析", isOn: $autoAnalyze)
            if analyzing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("生成中…").font(.callout).foregroundColor(.secondary)
                }
            }
            if let a = analysis {
                ForEach(a.candidates) { c in
                    Button {
                        UIPasteboard.general.string = c.text
                        notice = "已复制「\(c.tone)」候选，去输入框粘贴发送"
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.text).font(.callout).foregroundColor(.primary)
                            Text(c.tone + (c.prob.map { String(format: " · %.0f%%", $0 * 100) } ?? ""))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !a.notices.isEmpty {
                    Text(a.notices.joined(separator: "；")).font(.caption).foregroundColor(.orange)
                }
            }
            if let notice {
                Text(notice).font(.caption).foregroundColor(.secondary)
            }
        } header: {
            Text("建议")
        } footer: {
            Text("App 在前台时才会自动分析；锁屏或切走后由键盘接管——切到秒回键盘点「读屏幕分析」即可，同样免复制。")
        }
    }

    // MARK: 自检

    private var selfTestSection: some View {
        Section {
            Button {
                let img = LiveDebugFixtures.makeFakeChat()
                debugImage = img
                debugLines = LiveOCREngine.recognize(cgImage: img.cgImage!)
            } label: {
                Label("合成示例截图自检", systemImage: "photo.artframe")
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("从相册选聊天截图识别", systemImage: "photo.on.rectangle")
            }
            if !debugLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(debugLines.enumerated()), id: \.offset) { _, line in
                        Text("\(tag(line.side)) \(line.text)").font(.caption).monospaced()
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("自检（不开启广播也能验证 OCR）")
        }
    }

    private func tag(_ side: LiveLine.Side) -> String {
        switch side {
        case .them: return "[对方]"
        case .me: return "[我]"
        case .system: return "[系统]"
        }
    }

    // MARK: 轮询 + 自动分析

    private func tick() {
        let snap = JevLiveStore.load()
        snapshot = snap
        guard autoAnalyze, !analyzing,
              let snap, JevLiveStore.isFresh(snap),
              let latest = snap.latestIncoming else { return }
        guard latest != lastAnalyzed else { return }
        // 防抖：updatedAt 是画面最后一次变化的时间，稳定 2.5 秒后再分析，
        // 不然对方连发三条会生成三次、白烧前两次的 token
        guard Date().timeIntervalSince(snap.updatedAt) > 2.5 else { return }
        analyze(latest: latest, context: snap.contextText)
    }

    private func analyze(latest: String, context: String?) {
        analyzing = true
        lastAnalyzed = latest
        notice = nil
        let pipeline = JevPipeline(cfg: store.config)
        Task { @MainActor in
            let result = await pipeline.analyze(message: latest, context: context)
            analysis = result
            analyzing = false
            if let fatal = result.fatalError { notice = fatal }
        }
    }
}

// MARK: - 系统广播按钮（UIKit 桥接）

/// RPSystemBroadcastPickerView 是系统控件，点它弹系统面板（列出本 App 的广播扩展），
/// preferredExtension 让「秒回直播」排第一，用户基本只需再点一下「开始直播」。
struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.showsMicrophoneButton = false
        picker.preferredExtension = "com.jevchat.jarvis.ios.live"
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

// MARK: - 自检用合成聊天截图

enum LiveDebugFixtures {

    /// 画一张微信风格的假聊天图：对方靠左灰底、我方靠右主题色、居中时间戳。
    /// 用来在模拟器/不开广播的前提下验证「OCR → 左右归属」整条解析路径。
    static func makeFakeChat() -> UIImage {
        let size = CGSize(width: 390, height: 640)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(white: 0.949, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            drawCenter("20:31", y: 24, in: ctx.cgContext)
            bubble("在吗，周末的那个方案你看了一眼没", side: .them, y: 64, in: ctx.cgContext)
            bubble("看了看了，这两天有点忙", side: .me, y: 138, in: ctx.cgContext)
            bubble("周五之前给你一版完整的，带预算表", side: .me, y: 200, in: ctx.cgContext)
            bubble("行，记得把报价也放进去，老板要看价格", side: .them, y: 262, in: ctx.cgContext)
            bubble("好嘞", side: .me, y: 336, in: ctx.cgContext)
            bubble("对了上次说的那家餐厅，周末要不要去试试", side: .them, y: 396, in: ctx.cgContext)
            drawCenter("发送", y: 600, in: ctx.cgContext)   // 底部 UI，应该被清洗掉
        }
    }

    private static func drawCenter(_ text: String, y: CGFloat, in ctx: CGContext) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let s = NSAttributedString(string: text, attributes: attr)
        let w = s.size().width
        s.draw(at: CGPoint(x: (390 - w) / 2, y: y))
    }

    private static func bubble(_ text: String, side: LiveLine.Side, y: CGFloat, in ctx: CGContext) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label,
        ]
        let s = NSAttributedString(string: text, attributes: attr)
        var bounds = s.boundingRect(with: CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin], context: nil)
        bounds.size.width = ceil(bounds.width)
        bounds.size.height = ceil(bounds.height)
        let bubbleRect = CGRect(x: 0, y: y, width: bounds.width + 28, height: bounds.height + 20)
        let rect: CGRect = side == .them
            ? bubbleRect.offsetBy(dx: 64, dy: 0)
            : bubbleRect.offsetBy(dx: 390 - 64 - bubbleRect.width, dy: 0)

        let color: UIColor = side == .them ? .white : UIColor(red: 0.58, green: 0.86, blue: 0.44, alpha: 1)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        color.setFill()
        path.fill()

        let textOrigin = CGPoint(x: rect.minX + 14, y: rect.minY + 10)
        s.draw(at: textOrigin)
    }
}
