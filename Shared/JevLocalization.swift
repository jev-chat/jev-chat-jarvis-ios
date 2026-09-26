import Foundation

/// The language used by the app and keyboard extension. Stored in the App Group
/// so changing it in the app also updates the keyboard on its next render.
enum JevLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

func jevLocalized(_ language: JevLanguage, zh: String, en: String) -> String {
    language == .english ? en : zh
}

func localizedRiskLabel(_ score: Double, language: JevLanguage) -> String {
    let english = [
        "No risk; any reply is fine", "Very low risk", "Neutral; reply normally",
        "Be a little careful", "Somewhat sensitive; choose your words",
        "Be careful; it may be picked apart", "Risky; easy to offend or trip up",
        "Very risky; a wrong reply could cause trouble", "Extremely risky; responsibility or interests involved",
        "Critical risk; pause and think before replying",
    ]
    guard language == .english else { return riskLabel(for: score) }
    let idx = min(max(Int(score.rounded()), 0), english.count - 1)
    return english[idx]
}

func localizedIntent(_ intent: String, language: JevLanguage) -> String {
    guard language == .english else { return intent }
    return [
        "派活": "Task request", "催进度": "Chasing progress", "问进度": "Asking for progress",
        "批评": "Criticism", "要解释": "Asking for an explanation", "闲聊": "Small talk",
        "约会议": "Scheduling a meeting", "夸奖": "Praise",
    ][intent] ?? intent
}

func localizedActions(_ actions: [String], language: JevLanguage) -> [String] {
    guard language == .english else { return actions }
    let map = [
        "接住": "Acknowledge it", "问清交付标准和期限": "Clarify scope and deadline", "先给个时间点": "Give a time estimate",
        "先给当前状态": "State the current status", "给明确的完成时间": "Give a clear completion time", "别解释太多": "Keep explanations short",
        "直接说事实": "State the facts", "给下个节点": "Give the next milestone", "有卡点就说卡点": "Name any blocker",
        "先认下来": "Acknowledge it first", "别急着辩解": "Do not argue immediately", "给补救方案": "Offer a fix",
        "说清原因": "Explain the reason", "别找借口": "Do not make excuses", "给改进措施": "Give a corrective action",
        "轻松回应": "Reply casually", "可以互动": "Invite a response", "不用当真": "Do not overthink it",
        "确认时间": "Confirm the time", "说清议程": "Clarify the agenda", "准备好材料": "Prepare the materials",
        "接住并感谢": "Acknowledge and thank them", "别过度谦虚": "Do not over-apologize", "可以顺带提下一步": "Mention the next step",
    ]
    return actions.map { map[$0] ?? $0 }
}

func localizedToneName(_ name: String, language: JevLanguage) -> String {
    guard language == .english else { return name }
    return [
        "高情商话术": "High EQ", "贴吧老哥 v1.0": "Forum bro v1.0", "拒绝加班": "Decline overtime",
        "卑微乙方": "Humble vendor", "稳如老狗": "Calm engineer", "已读乱回": "Minimal reply",
        "鱼塘主": "The charmer", "职场黑话": "Corporate jargon", "阴阳怪气": "Sarcastic",
        "情绪价值": "Emotional support", "夸夸": "Hype friend", "讨好型人格": "People pleaser",
        NONE_LABEL: "Off",
    ][name] ?? name
}

func localizedProviderName(_ id: String, language: JevLanguage) -> String? {
    guard language == .english else { return nil }
    return [
        "zhipu": "Zhipu (free glm-4-flash)", "deepseek": "DeepSeek official",
        "openrouter": "OpenRouter", "dashscope": "Alibaba Qwen", "moonshot": "Moonshot Kimi",
        "siliconflow": "SiliconFlow", "ollama": "Ollama (local network)", "custom": "Custom…",
        "typesafe": "TypeSafe direct", "vercel": "Vercel AI Gateway",
    ][id]
}

func toneEnglishDescription(_ name: String) -> String {
    [
        "高情商话术": "A thoughtful coworker: acknowledge feelings, state facts, and offer a concrete next step.",
        "贴吧老哥 v1.0": "Internet slang, casual and self-deprecating, with no formal pleasantries.",
        "拒绝加班": "Set a calm, firm boundary and give a specific alternative time.",
        "卑微乙方": "An exaggeratedly humble vendor who agrees first and apologizes often.",
        "稳如老狗": "A calm engineer: short, factual, and anchored by a time or conclusion.",
        "已读乱回": "Brief and polite, acknowledging the message without promising or expanding.",
        "鱼塘主": "Cool and teasing, leaving room for curiosity without being oily or flirtatious.",
        "职场黑话": "Use professional buzzwords while keeping the sentence understandable.",
        "阴阳怪气": "Polite on the surface with a light, pointed edge; never direct abuse.",
        "情绪价值": "Validate the other person’s feelings before offering advice or solutions.",
        "夸夸": "Praise a specific detail warmly, then handle the practical request.",
        "讨好型人格": "Soft and eager to please, but still clear enough to send directly.",
    ][name] ?? (BUILTIN_TONES[name] ?? "")
}

extension JevStore {
    private static let languageKey = "jev.language.v1"

    static func loadLanguage() -> JevLanguage {
        guard let raw = defaults.string(forKey: languageKey),
              let language = JevLanguage(rawValue: raw) else { return .chinese }
        return language
    }

    static func saveLanguage(_ language: JevLanguage) {
        defaults.set(language.rawValue, forKey: languageKey)
    }
}
