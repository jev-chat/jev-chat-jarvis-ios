import Foundation

// MARK: - 缓存路径单一来源（写死 D 盘，支持环境变量覆盖）

/// 所有「会写磁盘」的路径都从这里出。
///
/// 默认根目录落在 **Windows D 盘在 macOS（Boot Camp 双系统）下的挂载点 `/Volumes/D/jev-ios-cache`**，
/// 保证 Xcode 派生数据（DerivedData）与 App 运行时缓存都不写进 Mac 系统卷
/// —— Mac 系统卷等效 Windows 的 C 盘，正是要避开的盘。
///
/// 可用环境变量 `JEV_CACHE_ROOT` 覆盖（传 POSIX 路径，如 `/Volumes/D/jev-ios-cache`）。
///
/// 设备侧说明：真机（iPhone/iPad）上不存在 `/Volumes/D`，此时「运行时缓存」会自动回退到
/// App 沙盒的 `Library/Caches` 目录（iOS 沙盒不允许 App 数据写到外部卷，属系统限制，构建缓存不受影响，
/// 因为构建发生在 Mac 上）。本机构建与模拟器运行都能正常命中 D 盘路径。
enum JevPaths {
    /// 缓存根。默认 D 盘挂载点；`JEV_CACHE_ROOT` 可覆盖。
    static var cacheRoot: URL {
        if let raw = ProcessInfo.processInfo.environment["JEV_CACHE_ROOT"], !raw.isEmpty {
            return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
        }
        return URL(fileURLWithPath: "/Volumes/D/jev-ios-cache")
    }

    // MARK: 构建缓存（Xcode 在 Mac 上产生）
    static let derivedData          = cacheRoot.appendingPathComponent("DerivedData")
    static let buildProducts        = cacheRoot.appendingPathComponent("Build/Products")
    static let buildIntermediates    = cacheRoot.appendingPathComponent("Build/Intermediates")
    static let precompiled          = cacheRoot.appendingPathComponent("Build/Precompiled")

    // MARK: 应用运行时缓存（调试日志、网络磁盘缓存等）
    static let runtimeCache         = cacheRoot.appendingPathComponent("runtime")
    static let logsDir              = cacheRoot.appendingPathComponent("logs")
    static let diagLogURL           = logsDir.appendingPathComponent("jev-diag.log")

    /// 确保目录存在，失败返回 false（用于真机回退判断）。
    @discardableResult
    static func ensure(_ dir: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// 真机安全的运行时缓存目录：D 盘可写就用 D 盘，否则回退沙盒 caches。
    static var safeRuntimeCache: URL {
        let preferred = runtimeCache
        if ensure(preferred), FileManager.default.isWritableFile(atPath: preferred.path) {
            return preferred
        }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? preferred
    }

    /// 打印当前解析出的所有缓存路径，便于构建/运行后核对是否真的落在 D 盘。
    static func dump() -> String {
        ensure(cacheRoot)
        return """
        [JevPaths] 缓存根        : \(cacheRoot.path)
        [JevPaths] DerivedData   : \(derivedData.path)
        [JevPaths] 构建产物       : \(buildProducts.path)
        [JevPaths] 中间产物       : \(buildIntermediates.path)
        [JevPaths] 预编译         : \(precompiled.path)
        [JevPaths] 运行时缓存(生效): \(safeRuntimeCache.path)
        [JevPaths] 调试日志       : \(diagLogURL.path)
        """
    }
}
