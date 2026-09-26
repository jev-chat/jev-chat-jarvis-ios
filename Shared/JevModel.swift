import Foundation

// MARK: - 配置模型

/// 生成层 API 形状。key 所在的组决定请求形状（与 macOS 版同一规则）。
enum APIKind: String, Codable, CaseIterable, Identifiable {
    case openai
    case anthropic

    var id: String { rawValue }
    var label: String {
        switch self {
        case .openai: return "OpenAI 兼容（/chat/completions）"
        case .anthropic: return "Anthropic 兼容（/v1/messages）"
        }
    }
}

struct ProviderPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: APIKind
    let base: String
    let model: String
    let keyHint: String

    /// DeepSeek 国内直连、智谱 glm-4-flash、OpenRouter、通义与本地 Ollama。
    static let all: [ProviderPreset] = [
        .init(id: "zhipu", name: "智谱（glm-4-flash 免费）", kind: .openai,
              base: "https://open.bigmodel.cn/api/paas/v4", model: "glm-4-flash", keyHint: "open.bigmodel.cn 的 API Key"),
        .init(id: "deepseek", name: "DeepSeek 官方", kind: .openai,
              base: "https://api.deepseek.com", model: "deepseek-chat", keyHint: "platform.deepseek.com 的 sk-…"),
        .init(id: "openrouter", name: "OpenRouter", kind: .openai,
              base: "https://openrouter.ai/api/v1", model: "deepseek/deepseek-chat-v3.1", keyHint: "sk-or-…"),
        .init(id: "dashscope", name: "阿里通义（兼容模式）", kind: .openai,
              base: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-flash", keyHint: "sk-…"),
        .init(id: "moonshot", name: "月之暗面 Kimi", kind: .openai,
              base: "https://api.moonshot.cn/v1", model: "moonshot-v1-8k", keyHint: "sk-…"),
        .init(id: "siliconflow", name: "硅基流动", kind: .openai,
              base: "https://api.siliconflow.cn/v1", model: "Qwen/Qwen2.5-7B-Instruct", keyHint: "sk-…"),
        .init(id: "ollama", name: "Ollama（Mac 局域网）", kind: .openai,
              base: "http://127.0.0.1:11434/v1", model: "qwen2.5:7b", keyHint: "随便填，如 ollama"),
        .init(id: "custom", name: "自定义…", kind: .openai, base: "", model: "", keyHint: ""),
    ]
}

/// 判断层预设。Jev native 在 waitlist，网关同形状只换地址+模型+key。
struct JudgePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let base: String
    let model: String
    let keyHint: String

    static let all: [JudgePreset] = [
        .init(id: "typesafe", name: "TypeSafe 直连",
              base: "https://api.typesafe.ai", model: "jev-latest",
              keyHint: "api.typesafe.ai 的 key"),
        .init(id: "openrouter", name: "OpenRouter 网关",
              base: "https://openrouter.ai/api/alpha/decisions", model: "typesafe/jev-1.13",
              keyHint: "OpenRouter 的 sk-or-…"),
        .init(id: "vercel", name: "Vercel AI Gateway",
              base: "https://ai-gateway.vercel.sh/v1/evaluate", model: "typesafe-ai/jev",
              keyHint: "Vercel AI Gateway 的 key"),
        .init(id: "custom", name: "自定义…", base: "", model: "", keyHint: ""),
    ]
}

/// 生成层实际生效的那一组。URL / key / 模型同源，不跨来源混搭——
/// 混搭就是拿 A 家的 key 调 B 家的端点，换来一个看不懂的 401。
struct GenCredentials {
    var kind: APIKind
    var base: String
    var key: String
    var model: String
    var extraJSON: String
}

/// 话术槽上限。iOS 比 macOS 少一个：手机屏幕高度有限，3 槽 × 2 条 = 最多 6 条候选
/// 会把键盘顶到半个屏幕以上，2 槽 4 条是屏幕占用与可选性的平衡点。
/// 存在的槽位依然保留在配置里（只是不参与），日后想放开只改这一个数。
let MAX_SLOTS = 2

/// 全部配置。存 App Group，键盘扩展与主 App 共享同一份。
struct JevConfig: Codable, Equatable {
    // 生成层（必须配置自己的服务地址、API Key 和模型）
    var genKind: APIKind = .openai
    var genBase: String = "https://open.bigmodel.cn/api/paas/v4"
    var genKey: String = ""
    var genModel: String = "glm-4-flash"
    /// 额外请求体字段（JSON），端点要靠额外字段关思考模式时填，如 {"enable_thinking":false}
    var genExtraJSON: String = ""

    // 判断层（Jev：意图 + 风险 + 排序，核心判断引擎）。
    // 没配 key 时管线自动退化为「盲起草」——只出候选、无意图/风险，运行时兜底而非配置开关。
    var judgeBase: String = "https://api.typesafe.ai"
    var judgeKey: String = ""
    var judgeModel: String = "jev-latest"

    /// 话术槽位。空串 = 不用（与 macOS 版 NONE_LABEL 同语义）。最多 3 槽。
    var slots: [String] = ["高情商话术", "稳如老狗"]

    /// 用户自定义话术（名字 = 说明），同名覆盖内置。
    var customTones: [String: String] = [:]

    var activeSlots: [String] { Array(slots.filter { !$0.isEmpty }.prefix(MAX_SLOTS)) }

    /// 生成层凭据完全来自用户配置，不会回退到项目提供的服务。
    var generation: GenCredentials {
        GenCredentials(kind: genKind, base: genBase, key: genKey,
                       model: genModel, extraJSON: genExtraJSON)
    }
}

/// 键盘侧回写的运行状态，主 App 的引导页用它判断「键盘装没装、全访问给没给」。
struct KeyboardStatus: Codable, Equatable {
    var lastSeen: Date
    var hasFullAccess: Bool
}

// MARK: - App Group 存储

/// 配置与状态的唯一存放点。键值放 App Group UserDefaults：
/// 键盘扩展只有拿到「允许完全访问」后才能读共享容器，正好与联网条件一致。
enum JevStore {
    static let appGroupID = "group.com.jevchat.jarvis"
    private static let configKey = "jev.config.v1"
    private static let removedGenerationBase = "http://101.132.131.220:11111/v1"
    private static let statusKey = "jev.kbstatus.v1"
    private static let canaryKey = "jev.canary.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// App Group 容器是否真的可写可读（签名没带上 entitlement 时 suite 会静默退化为私有容器）。
    static var groupWritable: Bool {
        let stamp = "t\(Date().timeIntervalSince1970)"
        defaults.set(stamp, forKey: canaryKey)
        return defaults.string(forKey: canaryKey) == stamp
    }

    static func loadConfig() -> JevConfig {
        guard let data = defaults.data(forKey: configKey),
              var cfg = try? JSONDecoder().decode(JevConfig.self, from: data) else {
            return JevConfig()
        }
        if cfg.genBase == removedGenerationBase {
            let preset = ProviderPreset.all.first { $0.id == "zhipu" }
            cfg.genKind = preset?.kind ?? .openai
            cfg.genBase = preset?.base ?? ""
            cfg.genKey = ""
            cfg.genModel = preset?.model ?? ""
            cfg.genExtraJSON = ""
            saveConfig(cfg)
        }
        return cfg
    }

    static func saveConfig(_ cfg: JevConfig) {
        if let data = try? JSONEncoder().encode(cfg) {
            defaults.set(data, forKey: configKey)
        }
    }

    static func loadKeyboardStatus() -> KeyboardStatus? {
        guard let data = defaults.data(forKey: statusKey),
              let s = try? JSONDecoder().decode(KeyboardStatus.self, from: data) else { return nil }
        return s
    }

    static func saveKeyboardStatus(_ s: KeyboardStatus) {
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: statusKey)
        }
    }

    /// 密钥展示用掩码
    static func masked(_ key: String) -> String {
        guard !key.isEmpty else { return "（未配置）" }
        if key.count <= 8 { return String(repeating: "•", count: max(key.count - 2, 2)) + String(key.suffix(2)) }
        return String(key.prefix(4)) + "…" + String(key.suffix(4))
    }

#if DEBUG
    private static let diagKey = "jev.diag.v1"

    /// 键盘侧自检日志。键盘扩展连不上 Xcode 看控制台，所以写进 App Group，
    /// 再用 `xcrun devicectl device copy from --domain-type appGroupDataContainer` 拉出来看。
    static func diag(_ line: String) {
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let prev = defaults.string(forKey: diagKey) ?? ""
        defaults.set(String((prev + "[\(stamp)] \(line)\n").suffix(6000)), forKey: diagKey)
    }
#endif
}
