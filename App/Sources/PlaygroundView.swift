import SwiftUI

/// 试一试页：直接在 App 里跑完整管线，验证配置是否通。
struct PlaygroundView: View {
    @EnvironmentObject private var store: ConfigStore
    @State private var message = "这个需求你今天跟一下，明天早上给我"
    @State private var running = false
    @State private var stage = ""
    @State private var analysis: Analysis?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 70)
                        .font(.subheadline)
                    Button {
                        run()
                    } label: {
                        if running {
                            HStack { ProgressView().controlSize(.small); Text(stage.isEmpty ? jevLocalized(store.language, zh: "分析中…", en: "Analyzing…") : stage) }
                        } else {
                            Label(jevLocalized(store.language, zh: "运行分析", en: "Run analysis"), systemImage: "play.fill")
                        }
                    }
                    .disabled(running || message.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text(jevLocalized(store.language, zh: "要回的消息", en: "Message to reply to"))
                } footer: {
                    Text(jevLocalized(store.language, zh: "和键盘走同一条链路：判断 → 每话术起草 → 排序。这里能通，键盘上就能通。", en: "This uses the same pipeline as the keyboard: judge → draft each tone → rank."))
                }

                if let a = analysis {
                    AnalysisResultView(analysis: a)
                }
            }
            .navigationTitle(jevLocalized(store.language, zh: "试一试", en: "Try it"))
        }
    }

    private func run() {
        running = true
        analysis = nil
        let pipeline = JevPipeline(cfg: store.config)
        let msg = message
        let language = store.language
        Task {
            let result = await pipeline.analyze(message: msg, context: nil) { s in
                Task { @MainActor in
                    switch s {
                    case .judging: stage = jevLocalized(language, zh: "判断中…", en: "Judging…")
                    case .drafting(let d, let t): stage = jevLocalized(language, zh: "生成中 \(d)/\(t)…", en: "Drafting \(d)/\(t)…")
                    case .ranking: stage = jevLocalized(language, zh: "排序中…", en: "Ranking…")
                    case .done: stage = jevLocalized(language, zh: "完成", en: "Done")
                    }
                }
            }
            await MainActor.run {
                analysis = result
                running = false
            }
        }
    }
}

/// 结果卡：判断头 + 候选列表（点复制）。
struct AnalysisResultView: View {
    @EnvironmentObject private var store: ConfigStore
    let analysis: Analysis

    var body: some View {
        Section {
            if let jr = analysis.judge {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(localizedIntent(jr.intent, language: store.language))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            Text(jevLocalized(store.language, zh: String(format: "风险 %.0f/9", jr.risk), en: String(format: "Risk %.0f/9", jr.risk)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(riskColor(jr.risk))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(riskColor(jr.risk).opacity(0.12), in: Capsule())
                        Spacer()
                        Text(String(format: "%.0f%% · %.1fs", jr.confidence * 100, analysis.elapsed))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(localizedRiskLabel(jr.risk, language: store.language)).font(.caption).foregroundStyle(riskColor(jr.risk))
                    if !jr.actions.isEmpty {
                        Text(jevLocalized(store.language, zh: "建议：", en: "Next: ") + localizedActions(jr.actions, language: store.language).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(analysis.candidates) { c in
                HStack(alignment: .top) {
                    Text(localizedToneName(c.tone, language: store.language))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                    Text(c.text).font(.subheadline)
                    Spacer()
                    if let p = c.prob {
                        Text(String(format: "%.0f%%", p * 100))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Button {
                        UIPasteboard.general.string = c.text
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }

            ForEach(analysis.notices, id: \.self) { n in
                Text("· " + n).font(.caption).foregroundStyle(.orange)
            }

            if let fatal = analysis.fatalError {
                Text(fatal).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text(jevLocalized(store.language, zh: "结果", en: "Results"))
        }
    }

    private func riskColor(_ r: Double) -> Color {
        switch r {
        case ..<3: return .green
        case ..<6: return .yellow
        case ..<8: return .orange
        default: return .red
        }
    }
}
