# 缓存路径配置（全部落在 D 盘）

本工程已把**所有会写磁盘的缓存**统一指向 Windows D 盘在 macOS（Boot Camp 双系统）下的挂载点
`/Volumes/D/jev-ios-cache`，确保不占用 Mac 系统卷（等效 Windows 的 C 盘）。

可用环境变量 `JEV_CACHE_ROOT` 覆盖根目录（传 POSIX 路径）。

## 1. 构建缓存 / 派生数据（DerivedData）

在 Mac 构建机上产生，已重定向到 D 盘：

| 产物 | 路径 |
|------|------|
| DerivedData（xcodebuild -derivedDataPath） | `$(JEV_CACHE_ROOT)/DerivedData` |
| SYMROOT（构建产物） | `$(JEV_CACHE_ROOT)/Build/Products` |
| OBJROOT（中间产物） | `$(JEV_CACHE_ROOT)/Build/Intermediates` |
| SHARED_PRECOMPS_DIR（预编译头） | `$(JEV_CACHE_ROOT)/Build/Precompiled` |

配置位置：
- `project.yml` → `options.derivedDataPath` 与 `settings.base` 的 `SYMROOT/OBJROOT/DERIVED_DATA_PATH/SHARED_PRECOMPS_DIR`
- `build.sh` 构建时显式再传一遍上述参数，双保险

## 2. 应用运行时缓存

由 `Shared/JevPaths.swift` 单一来源管理，默认根 `JEV_CACHE_ROOT`（即 `/Volumes/D/jev-ios-cache`）：

| 产物 | 路径 |
|------|------|
| 调试日志 `jev-diag.log`（键盘自检日志镜像） | `$(JEV_CACHE_ROOT)/logs/jev-diag.log` |
| 网络磁盘缓存（可选，env `JEV_USE_DISK_CACHE=1` 启用） | `$(JEV_CACHE_ROOT)/runtime` |

- 调试日志：在 `JevStore.diag()` 中，除写入 App Group（设备兼容）外，额外追加写一份到 D 盘文件。
- 网络缓存：默认 `ephemeral`（不写磁盘）；设 `JEV_USE_DISK_CACHE=1` 后走 `JevPaths.runtimeCache` 上的 `URLCache`。
- App 启动时（`JevJarvisApp.init()`，DEBUG）会 `print(JevPaths.dump())`，控制台可直接核对是否落在 D 盘。

### 真机限制（重要）

iPhone/iPad 沙盒**不允许** App 数据写到系统卷以外的位置，因此：
- **DerivedData / 构建缓存**：不受影响，构建发生在 Mac 上，始终在 D 盘。
- **App Group `UserDefaults`（配置/密钥/状态）**：iOS 强制放在沙盒系统卷，**无法重定向到 D 盘**，保留作设备兼容。
- **运行时文件缓存**：真机无 `/Volumes/D` 时，`JevPaths.safeRuntimeCache` 自动回退到沙盒 `Library/Caches`；模拟器与 Mac 构建正常命中 D 盘。

## 3. 一键构建（在 Mac 上）

```bash
chmod +x build.sh
./build.sh paths    # 仅打印解析出的缓存路径，确认在 D 盘
./build.sh sim      # 模拟器构建
./build.sh device   # 真机构建（需连设备 + 签名）
./build.sh archive  # 归档出 ipa（需付费证书 / TestFlight）
```

覆盖缓存根：

```bash
JEV_CACHE_ROOT=/Volumes/D/jev-ios-cache ./build.sh sim
```

## 4. 校验清单

- [ ] 构建前 `JevPaths.dump()` 打印的 `缓存根` 为 `/Volumes/D/jev-ios-cache`（非 `~/Library/...`）
- [ ] `~/Library/Developer/Xcode/DerivedData` 下不再生成本工程派生数据
- [ ] 模拟器运行后 `$(JEV_CACHE_ROOT)/logs/jev-diag.log` 有内容
- [ ] 真机运行：`JevPaths.dump()` 中 `运行时缓存(生效)` 回退为沙盒 `Library/Caches`（预期行为）
