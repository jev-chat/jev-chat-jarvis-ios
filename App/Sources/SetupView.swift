import SwiftUI
import Combine

/// 开始页：键盘装没装、完全访问给没给、共享配置通不通，一眼看清。
struct SetupView: View {
    @EnvironmentObject private var store: ConfigStore
    @State private var kbStatus: KeyboardStatus?
    @State private var groupOK = false

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                statusSection
                howSection
                privacySection
            }
            .navigationTitle("秒回")
            .onAppear { refresh() }
            .onReceive(timer) { _ in refresh() }
        }
    }

    private func refresh() {
        kbStatus = JevStore.loadKeyboardStatus()
        groupOK = JevStore.groupWritable
    }

    // MARK: 状态卡

    private var statusSection: some View {
        Section {
            row(icon: "keyboard", title: "键盘已启用",
                ok: kbStatus != nil && Date().timeIntervalSince(kbStatus!.lastSeen) < 90,
                detail: kbStatus.map {
                    "最近使用：\(timeAgo($0.lastSeen))"
                } ?? "还没检测到键盘被唤起过（在任意输入框里切换到秒回键盘即可）")

            row(icon: "lock.open", title: "允许完全访问",
                ok: kbStatus?.hasFullAccess == true,
                detail: kbStatus?.hasFullAccess == true
                    ? "已开启：键盘可以联网、读剪贴板"
                    : "未开启：键盘无法联网和读剪贴板，也不会出候选")

            row(icon: "externaldrive.connected.to.line.below", title: "App Group 共享",
                ok: groupOK, detail: groupOK
                    ? "配置可以同步到键盘"
                    : "共享容器不可用：请确认用 Xcode 把 App 和键盘扩展签在同一个 Team 下")
        } header: {
            Text("状态")
        } footer: {
            Text("键盘每次被唤起时会回写状态，这里每 2 秒刷新。")
        }
    }

    private func row(icon: String, title: String, ok: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ok ? Color.green : Color.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: 步骤

    private var howSection: some View {
        Section("三步启用") {
            step(1, "设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 秒回键盘")
            step(2, "回到「键盘」列表，点秒回键盘 → 打开「允许完全访问」")
            step(3, "去「模型」页填一个 API Key（智谱 glm-4-flash 免费），然后到微信里用：长按消息 → 复制 → 键盘上点「分析剪贴板」")
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(n))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    // MARK: 隐私

    private var privacySection: some View {
        Section("隐私边界") {
            Label("聊天内容只发给你自己配置的模型接口，无自建服务器、不落盘、不进日志", systemImage: "hand.raised")
            Label("Key 存在本机 App Group 私有容器，仅 App 与键盘可读", systemImage: "key")
            Label("候选只「插入」输入框，发送永远由你手动完成", systemImage: "square.and.arrow.down.on.square")
            Label("键盘不监听、不上传按键内容；完全访问可随时在系统设置里关闭或移除键盘", systemImage: "shield")
        }
        .font(.subheadline)
    }

    private func timeAgo(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 60 { return "\(Int(s)) 秒前" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        return "\(Int(s / 3600)) 小时前"
    }
}
