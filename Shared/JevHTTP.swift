import Foundation

// MARK: - 错误

enum JevError: LocalizedError {
    case config(String)
    case missingKey(String)
    case http(Int, String)
    case badJSON(String)
    case emptyReply
    /// 思考型模型把 max_tokens 吃光、正文 0 条——是模型选错，不是网络坏，必须单独报
    case thinkingOnly(String)
    case timeout(String, Double)
    case cancelled

    var errorDescription: String? {
        // 界面语言决定错误文案；stage 名是管线内部的中文代号，展示前先翻译
        let en = JevStore.loadLanguage() == .english
        let stageText: (String) -> String = { stage in
            en ? ["判断": "Judging", "排序": "Ranking", "起草": "Drafting"][stage] ?? stage : stage
        }
        switch self {
        case .config(let m): return en ? "Configuration issue: \(m)" : "配置问题：\(m)"
        case .missingKey(let n): return en ? "Missing API key: \(n)" : "缺少密钥：\(n)"
        case .http(let c, let m): return en ? "HTTP \(c): \(m)" : "HTTP \(c)：\(m)"
        case .badJSON(let m): return en ? "Unexpected response format: \(m)" : "返回格式不对：\(m)"
        case .emptyReply: return en ? "The model returned an empty response" : "模型返回了空内容"
        case .thinkingOnly(let m): return m
        case .timeout(let stage, let sec):
            return en
                ? String(format: "%@ timed out (no response within %.0f s)", stageText(stage), sec)
                : String(format: "%@ 超时（%.0f 秒内没返回）", stage, sec)
        case .cancelled: return en ? "Cancelled" : "已取消"
        }
    }
}

// MARK: - 带总预算的 HTTP POST

/// 每个分析阶段（判断/起草/排序）受一个总时长预算约束，而不是只靠 URLRequest 的空闲超时：
/// 空闲超时和重试是相乘关系，没有总预算时「3 次重试 × 60 秒超时」最坏是几分钟的转圈。
/// （这条规则来自社区 iOS 版踩过的真机坑，见 README。）
enum JevHTTP {
    static func postJSON(_ body: [String: Any], url: String, headers: [String: String],
                         budget: Double, stage: String, retries: Int = 1) async throws -> [String: Any] {
        guard let u = URL(string: url) else { throw JevError.config("端点不合法: \(url)") }
        let payload = try JSONSerialization.data(withJSONObject: body)
        let start = Date()
        var lastErr: Error?

        for attempt in 0...retries {
            let remaining = budget - Date().timeIntervalSince(start)
            guard remaining > 2 else { throw lastErr ?? JevError.timeout(stage, budget) }
            var req = URLRequest(url: u)
            req.httpMethod = "POST"
            req.timeoutInterval = remaining
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            req.httpBody = payload
            do {
                let (data, resp) = try await activeSession().data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return obj
                }
                let text = String(data: data, encoding: .utf8) ?? ""
                if (code == 429 || (500...599).contains(code)) && attempt < retries {
                    lastErr = JevError.http(code, String(text.prefix(200)))
                    let left = budget - Date().timeIntervalSince(start)
                    if left > 4 {
                        try? await Task.sleep(nanoseconds: UInt64(min(pow(2, Double(attempt)), left - 2) * 1_000_000_000))
                    }
                    continue
                }
                throw JevError.http(code, String(text.prefix(300)))
            } catch let e as JevError {
                throw e
            } catch {
                lastErr = error
                if attempt < retries {
                    let left = budget - Date().timeIntervalSince(start)
                    if left > 4 {
                        try? await Task.sleep(nanoseconds: UInt64(min(2.0, left - 2) * 1_000_000_000))
                    }
                    continue
                }
            }
        }
        if Date().timeIntervalSince(start) >= budget - 2 { throw JevError.timeout(stage, budget) }
        throw lastErr ?? JevError.http(0, "重试耗尽")
    }

    /// 键盘扩展内存有限，用 ephemeral 配置避免磁盘缓存。
    private static var session: URLSession?
    static func ephemeralSession() -> URLSession {
        if let s = session { return s }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 60
        let s = URLSession(configuration: cfg)
        session = s
        return s
    }

    /// 受控磁盘缓存会话：响应缓存落在 `JevPaths.runtimeCache`（即 D 盘）。
    /// 仅在环境变量 `JEV_USE_DISK_CACHE=1` 时启用，默认仍走 ephemeral 不写磁盘。
    private static var diskSession: URLSession?
    static func diskCacheSession() -> URLSession {
        if let s = diskSession { return s }
        JevPaths.ensure(JevPaths.runtimeCache)
        let cache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024,
            diskPath: JevPaths.runtimeCache.path
        )
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = cache
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 60
        let s = URLSession(configuration: cfg)
        diskSession = s
        return s
    }

    /// 统一会话入口：env 打开磁盘缓存时走 D 盘缓存会话，否则 ephemeral（默认）。
    static func activeSession() -> URLSession {
        ProcessInfo.processInfo.environment["JEV_USE_DISK_CACHE"] == "1"
            ? diskCacheSession()
            : ephemeralSession()
    }

    /// 容错解析：剥掉 markdown 围栏与前后杂字，取第一个 { 到最后一个 }。
    static func parseJSONObject(_ content: String) throws -> [String: Any] {
        var s = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
        }
        guard let a = s.firstIndex(of: "{"), let b = s.lastIndex(of: "}"), a < b,
              let obj = try? JSONSerialization.jsonObject(with: Data(s[a...b].utf8)) as? [String: Any] else {
            throw JevError.badJSON(String(content.prefix(200)))
        }
        return obj
    }
}
