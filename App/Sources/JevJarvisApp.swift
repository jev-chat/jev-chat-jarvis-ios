import SwiftUI

/// 配置的唯一可写入口：App 侧改完立刻落 App Group，键盘下次分析就能读到。
@MainActor
final class ConfigStore: ObservableObject {
    @Published var config: JevConfig {
        didSet { JevStore.saveConfig(config) }
    }

    init() {
        config = JevStore.loadConfig()
    }

    /// 键盘那边也能改共享配置（话术槽位就能直接在键盘上选），回到前台时把外部改动收进来——
    /// 否则 App 里这份旧值会在下次编辑时把键盘的选择覆盖掉。
    func reloadIfChanged() {
        let fresh = JevStore.loadConfig()
        if fresh != config { config = fresh }
    }

    var toneCatalog: [String: String] { allTones(custom: config.customTones) }
}

@main
struct JevJarvisApp: App {
    @StateObject private var store = ConfigStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                SetupView()
                    .tabItem { Label("开始", systemImage: "keyboard") }
                ProvidersView()
                    .tabItem { Label("模型", systemImage: "brain.head.profile") }
                TonesView()
                    .tabItem { Label("话术", systemImage: "theatermasks") }
                LiveView()
                    .tabItem { Label("直播", systemImage: "dot.radiowaves.left.and.right") }
                PlaygroundView()
                    .tabItem { Label("试一试", systemImage: "flask") }
            }
            .environmentObject(store)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.reloadIfChanged() }
        }
    }
}
