import Foundation

// MARK: - 判断层题目（与 macOS 版 src/judge.py 同口径，改这里要三端一起改）

/// 8 类意图：Jev choice 题的 criteria，同时是界面上的意图标签。
let INTENTS: [String: String] = [
    "派活": "对方要我做一件事或接一个任务",
    "催进度": "对方在催促我尽快完成某个已在办的事",
    "问进度": "对方在询问某件事的进展或状态",
    "批评": "对方对我的工作或结果表达不满、指出错误",
    "要解释": "对方要求我说明原因或给出解释",
    "闲聊": "对方只是在聊天、分享或表达感受，没有具体要求",
    "约会议": "对方想安排一次会议或通话",
    "夸奖": "对方在肯定、称赞我的成果",
]

/// 风险 0-9 分级（Jev score 题的 criteria，文案即量表）。
let RISK_LEVELS: [String] = [
    "完全没风险，怎么回都行",
    "基本没风险",
    "平淡，正常回就好",
    "需要稍微留神",
    "有点敏感，措辞注意",
    "需要谨慎，可能被挑刺",
    "比较危险，容易得罪人或踩坑",
    "很危险，说错要出问题",
    "非常危险，涉及责任或利益",
    "极度危险，先别回，想清楚再说",
]

/// 每个意图的行动建议（界面直接展示）。
let ACTION_MAP: [String: [String]] = [
    "派活": ["接住", "问清交付标准和期限", "先给个时间点"],
    "催进度": ["先给当前状态", "给明确的完成时间", "别解释太多"],
    "问进度": ["直接说事实", "给下个节点", "有卡点就说卡点"],
    "批评": ["先认下来", "别急着辩解", "给补救方案"],
    "要解释": ["说清原因", "别找借口", "给改进措施"],
    "闲聊": ["轻松回应", "可以互动", "不用当真"],
    "约会议": ["确认时间", "说清议程", "准备好材料"],
    "夸奖": ["接住并感谢", "别过度谦虚", "可以顺带提下一步"],
]

func riskLabel(for score: Double) -> String {
    let idx = min(max(Int(score.rounded()), 0), RISK_LEVELS.count - 1)
    return RISK_LEVELS[idx]
}

// MARK: - 话术库（与 macOS 版 src/styles.py 逐字一致）

/// 每条话术产出的候选条数：前一条稳妥可直接发，后一条把语气做足。
let PER_TONE = 2

/// 话术槽位的「关掉」哨兵值（沿用了 macOS 面板的语义）。
let NONE_LABEL = "不用"

/// 内置话术。说明写成「人设 + 口头禅 + 上限约束」而不是形容词——这是 macOS 版实测出的写法。
let BUILTIN_TONES: [String: String] = [
    "高情商话术": "像公司里那个谁都说好的老同事：先接住对方情绪（「我理解」「确实」），再说事实和下一步，拒绝也带替代方案加一个具体时间点。不说教、不绕圈子、句尾不堆「呢/哦/啦」。",
    "贴吧老哥 v1.0": "贴吧老哥：一口网感口语，「有一说一」「绷不住了」「搁这」「这就去整」随手就来，自称我、管对方叫「哥/兄弟」，可以自嘲玩梗甚至摆烂，但不骂人。禁止「您好」「感谢」这类书面客套。",
    "拒绝加班": "态度平和但把话说死：明确今天做不完，**不给**「我尽量」「看情况」这种会被继续压的口子；必须给一个具体替代时间（比如「明早九点前」），并说清不用等今晚。道歉不超过一句，理由不超过一句。",
    "卑微乙方": "极度卑微的乙方：「好的好的」「收到收到」「实在抱歉」「麻烦您了」张口就来，全程称「您」，任何问题先认在自己头上，随叫随到。夸张到一眼看出是梗，但整句仍然能直接发出去。",
    "稳如老狗": "十年老工程师那种稳：不解释、不铺垫、不道歉，只给结论加一个时间点，句子短、主语是事不是情绪（「三点前给你」「已确认，没问题」），让对方觉得事情已经稳了。",
    "已读乱回": "敷衍但不失礼：一到六个字把对方接住（「在忙，你说」「嗯嗯」「好」），不承诺、不展开、不给时间点，让对方觉得回了又没法接着追问。",
    "鱼塘主": "海王海后式回消息：我是塘主，对方只是鱼塘里的一条鱼。先推后拉——先淡淡降一句、再轻轻给个甜头；惜字如金，不解释、不道歉、不讨好；事情不说死、留点悬念，收尾自带先撤感（「先这样」）。嘴甜心硬，不主动不拒绝不负责——不揽活、不否认、不背锅。分寸在高冷从容，不油腻、不暧昧，不是撩。",
    "职场黑话": "把简单的事说得很专业：对齐、抓手、闭环、颗粒度、拉通、复盘、赋能、沉淀、打法轮着用，一句话里至少两个；但整句要能看懂，不要堆到不知所云。",
    "阴阳怪气": "表面客气、话里带刺：多用「哦」「呢」「那就」「辛苦你了」配反问或夸张的客气，让对方不好发作又不能说你没礼貌。不要升级成直接骂人或人身攻击。",
    "理科直男": "只回答被问到的：零寒暄、零情绪、零修饰、零表情，能两个字说清就不用五个字，像一个不太会说话但很靠谱的工程师。不做任何延伸，也不表示关心。",
]

/// 内置 + 自定义合并（同名覆盖）。顺序 = 界面下拉顺序。
func allTones(custom: [String: String]) -> [String: String] {
    var merged = BUILTIN_TONES
    for (k, v) in custom where k != NONE_LABEL && !v.isEmpty {
        merged[k] = v
    }
    return merged
}

// MARK: - 起草 prompt（沿用 macOS 版结构，面向通用聊天场景）

/// {n} 出现两次是刻意的：「只要 n 行」的要求必须与条数一致，否则模型会自己凑一行。
let PROMPT_ONE = """
刚收到一条聊天消息，你要帮我回。

{context_line}消息：「{message}」
{intent_line}
请写 {n} 条回复候选，语气统一成下面这一种，但两条的胆量要有差别：
「{tone}」{instruction}

硬性要求：
- 前一条稳妥、可以直接发出去；后一条把这个语气做足，更皮、更夸张一点也行
- 每条不超过 30 个字，像日常聊天时打字的语气，不要客套话、不要解释
- 只输出 {n} 行，每行一条，不要编号、不要引号、不要任何前后缀
- 不要写出语气名称（不要写「{tone}：」这类前缀），直接从回复内容开始
"""

func buildDraftPrompt(message: String, intent: String?, context: String?,
                      tone: String, instruction: String, n: Int) -> String {
    let contextLine = context != nil && !(context ?? "").isEmpty ? "最近的对话：\n\(context!)\n\n" : ""
    let intentLine = intent != nil && !(intent ?? "").isEmpty ? "判断出的意图：\(intent!)\n" : ""
    return PROMPT_ONE
        .replacingOccurrences(of: "{context_line}", with: contextLine)
        .replacingOccurrences(of: "{message}", with: message)
        .replacingOccurrences(of: "{intent_line}", with: intentLine)
        .replacingOccurrences(of: "{tone}", with: tone)
        .replacingOccurrences(of: "{instruction}", with: instruction)
        .replacingOccurrences(of: "{n}", with: String(n))
}

// MARK: - 候选清洗（移植自 generate.py _parse：模型「通常会」守规矩，所以要兜底）

enum CandidateParser {
    private static let numbering = try! NSRegularExpression(pattern: #"^[\d]+[.、)．]\s*"#)

    /// 「稳妥：」「轻松版：」这类模型偶尔回显的语气/风格前缀。冒号前只允许少量非标点填充。
    private static let styleLabel = try! NSRegularExpression(
        pattern: #"^[*_#\s]*(稳妥|轻松|简短|简洁)[^，。！？；、,.!?;：:]{0,5}[*_#\s]*[:：]\s*"#)
    private static let styleLabelShort = try! NSRegularExpression(
        pattern: #"^[*_#\s]*(简|稳|轻)\s*(型|洁)?[*_#\s]*[:：]\s*"#)

    private static func strip(_ s: String, _ re: NSRegularExpression) -> String {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = re.firstMatch(in: s, range: range),
              let r = Range(m.range, in: s) else { return s }
        return String(s[r.upperBound...])
    }

    private static let quotePairs: [(Character, Character)] = [
        ("\"", "\""), ("'", "'"), ("“", "”"), ("‘", "’"), ("「", "」"), ("『", "』"),
    ]

    private static func stripQuotes(_ s: String) -> String {
        var t = s
        for (open, close) in quotePairs where t.first == open && t.last == close && t.count >= 2 {
            t.removeFirst(); t.removeLast()
        }
        return t
    }

    /// 一行原始输出 → 一条干净候选。编号 → 引号 → 风格前缀 → 引号，与 macOS 版同顺序。
    static func parseLine(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return nil }
        s = strip(s, numbering)
        s = stripQuotes(s)
        s = strip(s, styleLabel)
        s = strip(s, styleLabelShort)
        s = stripQuotes(s)
        s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }

    static func parse(_ raw: String, limit: Int = PER_TONE) -> [String] {
        var out: [String] = []
        for line in raw.split(separator: "\n") {
            if let t = parseLine(String(line)), !out.contains(t) {
                out.append(t)
                if out.count >= limit { break }
            }
        }
        return out
    }
}
