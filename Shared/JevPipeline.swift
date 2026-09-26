import Foundation

// MARK: - 端到端管线：判断 → 起草（每话术并发）→ 排序
//
// 阶段间是「带截止时间的串行」：判断通常 ~1 秒，等它出来再把意图喂给起草，
// 候选质量明显更好；判断超时或没配 key 时直接盲起草（Windows 版同款回退）。
// 排序失败按「每个话术的第 1 条（稳妥款）在前」的默认顺序展示。

struct Candidate: Identifiable, Equatable {
    var id: String { text }
    var text: String
    var tone: String
    /// Jev 排序概率；没排序时为 nil
    var prob: Double?
}

struct Analysis: Equatable {
    var message: String
    var judge: JudgeResult?
    var candidates: [Candidate] = []
    /// 非致命错误（某话术失败、排序失败），界面黄条展示
    var notices: [String] = []
    /// 致命错误（生成层全挂），界面红条展示
    var fatalError: String?
    var elapsed: Double = 0
    /// 候选已经出来了、但排序还没回来（界面据此提示"排序中"，并允许先点候选）
    var rankingPending: Bool = false
}

enum PipelineStage: Equatable {
    case judging
    case drafting(done: Int, total: Int)
    case ranking
    case done
}

final class JevPipeline {
    private let cfg: JevConfig
    private let judge: JevJudge
    private let draft: JevDraft

    init(cfg: JevConfig) {
        self.cfg = cfg
        self.judge = JevJudge(cfg: cfg)
        self.draft = JevDraft(cfg: cfg)
    }

    var generationConfigured: Bool { draft.isConfigured }

    /// 完整分析。永不 throw：致命问题进 fatalError，其余进 notices。
    ///
    /// 时间预算上的取舍（实测：模型服务每次请求光"出第一个字"就要 1.5 秒上下，
    /// 而且两条并发请求是真并发、不被排队），所以**减少串行等待**比压缩单次耗时更有效：
    ///   · 判断结果按消息缓存：同一条消息再分析（主要是「换一批」）不再花那次往返；
    ///   · 每条话术的候选一到就通过 onPartial 交给界面，不等其余话术、更不等排序。
    func analyze(message: String, context: String?,
                 onStage: ((PipelineStage) -> Void)? = nil,
                 onPartial: ((Analysis) -> Void)? = nil) async -> Analysis {
        let start = Date()
        var out = Analysis(message: message)

        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else {
            out.fatalError = "消息内容为空：请先在聊天里长按消息点「复制」，或把要回的话输进输入框"
            return out
        }
        guard draft.isConfigured else {
            out.fatalError = "还没配置生成层：打开 Jev Jarvis App →「模型」页填 API Key"
            return out
        }

        // 1) 判断层：起跑，但**不阻塞起草**。
        //
        // 为什么不串行等它：实测每次请求光"出第一个字"就要 1.5 秒上下，而喂给起草模型的那句
        // "意图"只是一个标签（真正决定候选风格的是话术指令）——A/B 实测盲起草与带意图起草的
        // 候选几乎没差别。所以让判断与起草重叠，意图的作用由「排序」这一层体现（它本来就用意图
        // 决定名次）；万一判断给出的是高风险消息，再用意图重写一版候选替换（见下面的 refine）。
        //
        // 同一条消息的判断结果带缓存：换一批时连这一次都不用跑。
        var judgeResult = judge.isConfigured
            ? JevJudgeCache.shared.get(message: msg, context: context)
            : nil
        var judgeTask: Task<JudgeResult?, Never>?
        if judge.isConfigured, judgeResult == nil {
            onStage?(.judging)
            judgeTask = Task { [judge] in
                let r = try? await judge.judge(message: msg, context: context)
                if let r { JevJudgeCache.shared.put(r, message: msg, context: context) }
                return r
            }
        }

        // 2) 起草：一个话术一次请求，并发；不等判断、也不等齐——每完成一个就先交给界面
        let tones = allTones(custom: cfg.customTones)
        let active = cfg.activeSlots.compactMap { name -> (String, String)? in
            guard let instruction = tones[name] else { return nil }
            return (name, instruction)
        }
        guard !active.isEmpty else {
            out.fatalError = "所有话术槽都是「不用」：打开 App →「话术」页至少启用一个"
            out.elapsed = Date().timeIntervalSince(start)
            return out
        }

        // 判断命中缓存时，第一轮就直接带意图（不用等，也没损失）
        let firstIntent = judgeResult?.intent
        func partial(with round: DraftRound, judge: JudgeResult?, extraNotices: [String] = []) -> Analysis {
            var p = out
            p.judge = judge
            p.candidates = Self.ordered(active.map(\.0), round.candidates)
            p.notices = out.notices + round.notices + extraNotices
            p.rankingPending = true
            p.elapsed = Date().timeIntervalSince(start)
            return p
        }

        onStage?(.drafting(done: 0, total: active.count))
        var round = await draftRound(active: active, msg: msg, intent: firstIntent, context: context,
                                     onStage: onStage) { r in
            onPartial?(partial(with: r, judge: JevJudgeCache.shared.get(message: msg, context: context)))
        }
        out.notices += round.notices
        var drafted = round.candidates

        // 判断落地：给排序用。等它有时间上限，别让一个卡住的上游拖住整条链路。
        if let t = judgeTask, judgeResult == nil {
            judgeResult = try? await withTimeout(seconds: 4) { await t.value }
        }
        out.judge = judgeResult
        if judge.isConfigured, judgeResult == nil {
            out.notices.append("判断层没响应，已盲起草（不影响出候选）")
        }

        // 2b) 高风险消息才用意图重写一版：盲起草在平常用消息上够用，风险高的才值得多花一次往返。
        if let jr = judgeResult, firstIntent == nil, jr.risk >= Self.refineRiskThreshold, !drafted.isEmpty {
            let note = String(format: "风险 %.0f/9：已按判断重写一版候选", jr.risk)
            round = await draftRound(active: active, msg: msg, intent: jr.intent, context: context,
                                     onStage: onStage) { r in
                onPartial?(partial(with: r, judge: jr, extraNotices: [note]))
            }
            if !round.candidates.isEmpty {
                drafted = round.candidates
                out.notices += round.notices
                out.notices.append(note)
            }
        }

        guard !drafted.isEmpty else {
            out.fatalError = out.notices.first ?? "候选生成失败：请到 App「模型」页点「测试连接」检查配置"
            out.elapsed = Date().timeIntervalSince(start)
            return out
        }

        // 3) 排序（可选）。失败按默认顺序：同话术的稳妥款在前。
        let ordered = Self.ordered(active.map(\.0), drafted)
        if judge.isConfigured, let jr = judgeResult {
            onStage?(.ranking)
            if let ranked = try? await withTimeout(seconds: 10, {
                try await self.judge.rank(message: msg, intent: jr.intent,
                                          candidates: ordered.map(\.text))
            }) {
                // 同一句话可能被两个话术各出一条（去重前不能拿它当字典的唯一 key，会 trap）。
                let toneBy = Dictionary(ordered.map { ($0.text, $0.tone) },
                                        uniquingKeysWith: { first, _ in first })
                let mapped = ranked.compactMap { r -> Candidate? in
                    guard let tone = toneBy[r.text] else { return nil }
                    return Candidate(text: r.text, tone: tone, prob: r.prob)
                }
                if mapped.isEmpty {
                    // 排序层回传的文本和候选对不上（模型改写了标点/空格）——宁可退回未排序的全量候选，
                    // 也不能让界面变成「判断头 + 一片空白」。
                    out.notices.append("排序结果和候选对不上，已按默认顺序展示")
                    out.candidates = ordered
                } else {
                    out.candidates = mapped
                }
            } else {
                out.notices.append("排序失败，按默认顺序展示")
                out.candidates = ordered
            }
        } else {
            out.candidates = ordered
        }

        out.elapsed = Date().timeIntervalSince(start)
        onStage?(.done)
        return out
    }

    /// 按话术槽的顺序整理候选（每个槽内部保持模型给出的顺序：前稳后放）
    private static func ordered(_ tones: [String], _ drafted: [Candidate]) -> [Candidate] {
        tones.flatMap { name in drafted.filter { $0.tone == name } }
    }

    /// 风险达到这个分数才值得用意图重写候选（0-9 分制，6 起是"需要谨慎"那一档）。
    /// 平常用消息不花这一次往返——实测盲起草与带意图起草的候选差别很小。
    private static let refineRiskThreshold: Double = 6

    /// 一轮起草的结果
    struct DraftRound {
        var candidates: [Candidate] = []
        var notices: [String] = []
    }

    /// 跑一轮起草：每个话术一次请求（并发），每完成一个就把"到目前为止的候选"交给界面。
    private func draftRound(active: [(String, String)], msg: String, intent: String?, context: String?,
                            onStage: ((PipelineStage) -> Void)?,
                            onPartial: @escaping (DraftRound) -> Void) async -> DraftRound {
        var round = DraftRound()
        await withTaskGroup(of: (String, [String], String?).self) { group in
            for (name, instruction) in active {
                group.addTask {
                    do {
                        let texts = try await self.draft.draft(
                            message: msg, intent: intent, context: context,
                            tone: name, instruction: instruction)
                        return (name, texts, nil)
                    } catch {
                        return (name, [], error.localizedDescription)
                    }
                }
            }
            var done = 0
            for await (name, texts, err) in group {
                done += 1
                onStage?(.drafting(done: done, total: active.count))
                if let err { round.notices.append("「\(name)」失败：\(err)") }
                for t in texts { round.candidates.append(Candidate(text: t, tone: name, prob: nil)) }
                // 先出一条是一条：不等其余话术、更不等排序
                if !round.candidates.isEmpty { onPartial(round) }
            }
        }
        return round
    }

    // MARK: 超时包装（阶段级截止时间，比预算更硬：到点放弃该阶段而不是拖慢整体）
    private func withTimeout<T: Sendable>(seconds: Double, _ op: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw JevError.timeout("", seconds)
            }
            guard let first = try await group.next() else {
                throw JevError.cancelled
            }
            group.cancelAll()
            return first
        }
    }
}
