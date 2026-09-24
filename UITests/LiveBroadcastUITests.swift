import XCTest

/// 直播模式端到端真机用例（USB 连着真机 `xcodebuild test` 就能全自动跑）：
/// 启动 App → 直播 tab → 点广播按钮 → 系统面板点「开始直播」→
/// 断言进入监听（心跳快照）→ 断言收到帧 → 持续 60 秒不掉线（回归 9/24 的「秒死」问题）→ 停播。
/// OCR 的文字质量不在 UI 层断言，跑完后从 App Group 拉 plist 查 lines/diag。
final class LiveBroadcastUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLiveBroadcastEndToEnd() throws {
        let app = XCUIApplication()
        app.launch()

        let tab = app.tabBars.buttons["直播"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "找不到「直播」tab")
        tab.tap()

        let picker = app.descendants(matching: .any)
            .matching(identifier: "broadcastPicker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "找不到广播按钮（accessibility identifier=broadcastPicker）")
        print("PICKER TREE:\n\(picker.debugDescription)")
        // 用真实触摸坐标点（accessibility activate 可能不触发 RPSystemBroadcastPickerView 的内部手势）
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // 系统广播面板挂在 SpringBoard 进程里，中英文设备都试
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let start = springboard.buttons.matching(
            NSPredicate(format: "label IN {'开始直播', 'Start Broadcast'}")).firstMatch
        if !start.waitForExistence(timeout: 8) {
            picker.tap()   // 兜底：无障碍激活再试一次
        }
        if !start.waitForExistence(timeout: 8) {
            // 诊断进结果包：SpringBoard 元素树 + 截图，看面板到底弹没弹、按钮叫什么
            print("SPRINGBOARD TREE:\n\(springboard.debugDescription)")
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "broadcast-sheet-missing"
            shot.lifetime = .keepAlways
            add(shot)
            XCTFail("系统广播面板没弹出来（两种点法都试过）")
        }
        start.tap()

        // ① 心跳：broadcastStarted 一落盘，状态 1-2 秒内就该翻绿
        let listening = app.staticTexts["监听中"]
        XCTAssertTrue(listening.waitForExistence(timeout: 20), "开播 20 秒内没进入「监听中」（心跳快照没写出来？）")

        // ② 帧：processSampleBuffer 在跑（状态行出现「已识别 N 帧」）
        let frames = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '已识别'")).firstMatch
        XCTAssertTrue(frames.waitForExistence(timeout: 30), "开播 30 秒内没收到任何视频帧")

        // ③ 关键回归（2026-09-24 真机首测「一直未在监听」）：扛住 60 秒不被系统杀
        sleep(60)
        XCTAssertTrue(app.staticTexts["监听中"].exists, "60 秒后监听状态丢失，扩展疑似被杀")

        // ④ 停播：再点一次广播按钮，同一个面板里变成「停止广播」
        picker.tap()
        let stop = springboard.buttons.matching(
            NSPredicate(format: "label IN {'停止广播', 'Stop Broadcast'}")).firstMatch
        if stop.waitForExistence(timeout: 8) {
            stop.tap()
        } else {
            XCTFail("没找到「停止广播」按钮，可能需要手动停一下（状态栏紫胶囊）")
        }
    }
}
