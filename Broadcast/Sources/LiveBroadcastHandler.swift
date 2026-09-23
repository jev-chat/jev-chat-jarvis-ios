import ReplayKit
import CoreVideo

// MARK: - 直播模式广播扩展
//
// 用户在主 App 点系统广播按钮后，iOS 把整块屏幕的帧喂到这里。三点约束决定了写法：
//   · 内存 ~50MB jetsam 硬上限：只做 OCR 与落盘，LLM 调用留给键盘/主 App；
//     识别包 autoreleasepool、fast 档、非视频帧直接丢弃。
//   · 回调队列被阻塞 = ReplayKit 自动丢帧：同步识别 2 秒一帧正好利用这一点节流，
//     不需要自己管理缓冲。
//   · 没有任何 UI：结果只能写 App Group 快照，由键盘与主 App 呈现。

final class LiveBroadcastHandler: RPBroadcastSampleHandler {

    /// OCR 节流周期。聊天画面一秒内的变化远低于此频率；2 秒兼顾实时性与耗电。
    private static let interval: TimeInterval = 2.0

    private var lastOCRAt = Date.distantPast
    private var lastSignature = ""
    private var framesSeen = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastOCRAt = .distantPast
        lastSignature = ""
        framesSeen = 0
    }

    override func broadcastFinished() {
        // 无需清理：快照靠 JevLiveStore.freshWindow 自然过期
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        framesSeen += 1
        let now = Date()
        guard now.timeIntervalSince(lastOCRAt) >= Self.interval else { return }
        lastOCRAt = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let lines = LiveOCREngine.recognize(pixelBuffer: pixelBuffer)
        // 画面没变就不重写快照：updatedAt 保持上一次变化的时间，主 App 靠它防抖
        let signature = lines.map(\.text).joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature
        JevLiveStore.save(LiveSnapshot(updatedAt: Date(),
                                       lines: Array(lines.suffix(40)),
                                       frameCount: framesSeen))
    }
}
