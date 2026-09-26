import SwiftUI
import UIKit

/// 模型页：生成层（必需）+ 判断层（可选）。改完即存，键盘下次分析生效。
struct ProvidersView: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        NavigationStack {
            Form {
                judgeSection
                generationSection
            }
            .navigationTitle(jevLocalized(store.language, zh: "模型", en: "Models"))
        }
    }

    // MARK: 生成层

    private var generationSection: some View {
        Section {
            Picker(jevLocalized(store.language, zh: "预设", en: "Preset"), selection: $preset) {
                ForEach(ProviderPreset.all) { p in
                    Text(localizedProviderName(p.id, language: store.language) ?? p.name).tag(p.id)
                }
            }
            .onChange(of: preset) { id in
                applyPreset(id)
            }

            Picker(jevLocalized(store.language, zh: "API 形状", en: "API format"), selection: $store.config.genKind) {
                ForEach(APIKind.allCases) { k in
                    Text(store.language == .english
                         ? (k == .openai ? "OpenAI-compatible (/chat/completions)" : "Anthropic-compatible (/v1/messages)")
                         : k.label).tag(k)
                }
            }

            TextField(jevLocalized(store.language, zh: "服务地址", en: "Service URL"), text: $store.config.genBase)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.footnote)

            KeyField(title: "API Key", text: $store.config.genKey)

            TextField(jevLocalized(store.language, zh: "模型", en: "Model"), text: $store.config.genModel)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.footnote)

            TextField(jevLocalized(store.language, zh: "额外字段 JSON（可选）", en: "Extra JSON fields (optional)"), text: $store.config.genExtraJSON, axis: .vertical)
                .font(.footnote.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .lineLimit(1...3)

            TestConnectionButton(kind: .generation)

            Text(genStatusLine)
                .font(.caption2).foregroundStyle(.secondary)
        } header: {
            Text(jevLocalized(store.language, zh: "生成层（候选回复，必配）", en: "Generation (required for suggestions)"))
        } footer: {
            Text(jevLocalized(store.language, zh: "必须填写你自己的 API Key；本项目不提供生成服务或中转。别用思考型模型（思考会占满额度导致 0 条候选）。地址带不带 /v1 都能拼对；端点需要额外字段关闭思考时，可在上面填写 JSON。", en: "Enter your own API key. This project does not provide a generation service or relay. Avoid reasoning models that spend the whole budget. URLs work with or without /v1; use the extra JSON field if your endpoint needs reasoning disabled."))
        }
    }

    private var genStatusLine: String {
        let g = store.config.generation
        return jevLocalized(store.language,
                            zh: "当前：\(g.kind.rawValue) · \(g.model) · Key \(maskedKey(g.key))",
                            en: "Current: \(g.kind.rawValue) · \(g.model) · Key \(maskedKey(g.key))")
    }

    private func maskedKey(_ key: String) -> String {
        key.isEmpty && store.language == .english ? "(not configured)" : JevStore.masked(key)
    }

    @State private var preset: String = "zhipu"

    private func applyPreset(_ id: String) {
        guard let p = ProviderPreset.all.first(where: { $0.id == id }), p.id != "custom" else { return }
        store.config.genKind = p.kind
        store.config.genBase = p.base
        store.config.genModel = p.model
    }

    // MARK: 判断层

    @State private var judgePreset: String = "typesafe"

    private var judgeSection: some View {
        Section {
            Picker(jevLocalized(store.language, zh: "预设", en: "Preset"), selection: $judgePreset) {
                ForEach(JudgePreset.all) { p in
                    Text(localizedProviderName(p.id, language: store.language) ?? p.name).tag(p.id)
                }
            }
            .onChange(of: judgePreset) { id in
                if let p = JudgePreset.all.first(where: { $0.id == id }), p.id != "custom" {
                    store.config.judgeBase = p.base
                    store.config.judgeModel = p.model
                }
            }

            TextField(jevLocalized(store.language, zh: "服务地址", en: "Service URL"), text: $store.config.judgeBase)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.footnote)
            KeyField(title: "API Key", text: $store.config.judgeKey)
            TextField(jevLocalized(store.language, zh: "模型", en: "Model"), text: $store.config.judgeModel)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.footnote)

            TestConnectionButton(kind: .judge)

            Text(jevLocalized(store.language, zh: "当前：\(store.config.judgeModel) · Key \(maskedKey(store.config.judgeKey))", en: "Current: \(store.config.judgeModel) · Key \(maskedKey(store.config.judgeKey))"))
                .font(.caption2).foregroundStyle(.secondary)
        } header: {
            Text(jevLocalized(store.language, zh: "判断层（Jev · 意图 + 风险 + 排序）", en: "Judge (Jev · intent + risk + ranking)"))
        } footer: {
            Text(jevLocalized(store.language, zh: "核心判断引擎：一次调用出 8 类意图概率和 0–9 风险分布，并给候选排序。没填 key 时键盘退化为「盲起草」（只出候选）。网关地址填到动作段或带 /v1 都能拼对；key 与生成层可以不是同一家。", en: "The judge returns probabilities for 8 intents, a 0–9 risk score, and candidate ranking. Without a key, the keyboard falls back to drafting only. The judge and generation providers can differ."))
        }
    }
}

// MARK: - 密钥输入框（默认明文方便粘贴核对，眼睛切换掩码）

private struct KeyField: View {
    let title: String
    @Binding var text: String
    /// 默认闭眼（掩码）。点开只是"本次看一眼"，离开或再回来都会重新闭上。
    @State private var hidden = true

    var body: some View {
        HStack(spacing: 8) {
            if hidden {
                SecureField(title, text: $text)
                    .font(.footnote)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                TextField(title, text: $text)
                    .font(.footnote)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Button {
                hidden.toggle()
            } label: {
                Image(systemName: hidden ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        // 默认闭眼：进这个页面就是掩码状态，想核对/粘贴时点一下眼睛看本次。
        // 出现和离开都复位（TabView 切回来时 onAppear 不一定再触发，两个都挂才不漏）；
        // 初始值也是 true，避免重建视图时先闪一下明文。
        .onAppear { hidden = true }
        .onDisappear { hidden = true }
    }
}

// MARK: - 测试连接

private struct TestConnectionButton: View {
    enum Kind { case generation, judge }
    let kind: Kind

    @EnvironmentObject private var store: ConfigStore
    @State private var running = false
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                test()
            } label: {
                if running {
                    HStack { ProgressView().controlSize(.small); Text(jevLocalized(store.language, zh: "测试中…", en: "Testing…")) }
                } else {
                    Label(jevLocalized(store.language, zh: "测试连接", en: "Test connection"), systemImage: "bolt.horizontal")
                }
            }
            .disabled(running)

            if let result {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("✅") ? Color.green : Color.red)
            }
        }
    }

    private func test() {
        // 先把键盘收掉：不然结果被键盘挡着，也会出现"点测试反而把键盘带出来"的观感
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        running = true
        result = nil
        let cfg = store.config
        Task {
            do {
                switch kind {
                case .generation:
                    let draft = JevDraft(cfg: cfg)
                    guard draft.isConfigured else { throw JevError.missingKey("生成层 API Key") }
                    let text = try await draft.call(prompt: "回复两个字：收到")
                    result = "✅ 成功，模型回了：\(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))"
                case .judge:
                    let judge = JevJudge(cfg: cfg)
                    guard judge.isConfigured else { throw JevError.missingKey("判断层 API Key") }
                    let jr = try await judge.judge(message: "这个需求你今天跟一下", context: nil)
                    result = String(format: "✅ 成功：意图「%@」（%.0f%%），风险 %.1f/9", jr.intent, jr.confidence * 100, jr.risk)
                }
            } catch {
                result = "❌ \(error.localizedDescription)"
            }
            running = false
        }
    }
}
