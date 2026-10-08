# Mac 端编译与真机运行指南（缓存全部落在 D 盘）

> 适用场景：本机为 Windows + macOS 双系统（Boot Camp），Windows 的 **D 盘**在 macOS 下挂载为 `/Volumes/D`。
> 目标：在 Mac 上编译 `jev-chat-jarvis-ios`，**构建缓存（DerivedData / Build / Precompiled）与运行时缓存全部写入 `/Volumes/D/jev-ios-cache`，不写 C 盘（macOS 上即系统盘 `~/Library/Developer/Xcode/DerivedData`）**。

---

## 0. 前置条件（在 Mac 上）

- macOS + Xcode（建议 Xcode 15/16，App Store 安装）
- Xcode Command Line Tools：`xcode-select --install`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（用 `project.yml` 生成 `.xcodeproj`）：
  ```bash
  brew install xcodegen
  # 或： mint install yonaskolb/XcodeGen
  ```
- D 盘已挂载并可写：
  ```bash
  ls /Volumes/D          # 应能看到你的 Windows D 卷
  touch /Volumes/D/.writetest && echo "D 盘可写" && rm /Volumes/D/.writetest
  ```
- Apple ID（免费即可跑模拟器；真机签名 + App Group 需付费 $99 开发者账号，见第 6 节说明）
- 仓库已克隆到 Mac 本地（从你自己的 fork 拉取）：
  ```bash
  git clone https://github.com/luoxiaolong199303-sys/jev-chat-jarvis-ios.git
  cd jev-chat-jarvis-ios
  git checkout feat/ios-cache-d-drive
  ```

---

## 1. 生成 Xcode 工程

`project.yml` 已内置缓存路径重定向，且 Team ID / entitlements 改由环境变量驱动（`${ENV:JEV_TEAM_ID}` 等）。**推荐直接用 `build.sh`**，它会先注入这些环境变量再调 `xcodegen`：

```bash
./build.sh sim          # 内部执行 xcodegen generate（已注入 JEV_* 环境变量）→ 产出 JevJarvis.xcodeproj
```

若坚持裸跑 `xcodegen`，需先导出环境变量，否则 `${ENV:...}` 解析为空会报错：

```bash
export JEV_TEAM_ID=75LZ93U5CF
export JEV_APP_ENTITLEMENTS=App/JevJarvis.entitlements
export JEV_KB_ENTITLEMENTS=Keyboard/JevKeyboard.entitlements
xcodegen generate      # 读取 project.yml → 产出 JevJarvis.xcodeproj
```

生成后可用 `open JevJarvis.xcodeproj` 在 Xcode 中打开。

---

## 2. 预建缓存目录（可选，build.sh 会自动建）

```bash
mkdir -p /Volumes/D/jev-ios-cache/{DerivedData,Build/Products,Build/Intermediates,Build/Precompiled,runtime,logs}
```

如需临时改路径，传入环境变量（代码中 `JevPaths.cacheRoot` 会优先读它）：

```bash
export JEV_CACHE_ROOT=/Volumes/D/jev-ios-cache
```

---

## 3. 编译：模拟器版（最常用）

### 方式 A：用自带脚本（推荐）

```bash
./build.sh sim          # Debug + iphonesimulator，缓存全部走 D 盘
```

### 方式 B：裸 xcodebuild（便于排查）

```bash
xcodebuild -project JevJarvis.xcodeproj \
  -scheme JevJarvis \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath /Volumes/D/jev-ios-cache/DerivedData \
  SYMROOT=/Volumes/D/jev-ios-cache/Build/Products \
  OBJROOT=/Volumes/D/jev-ios-cache/Build/Intermediates \
  SHARED_PRECOMPS_DIR=/Volumes/D/jev-ios-cache/Build/Precompiled
```

---

## 4. 运行：模拟器

```bash
# 在 Xcode 里选模拟器设备后 ⏵ Run 即可；
# 或用命令行拉起：
xcrun simctl boot "iPhone 16"            # 设备名按你装的模拟器调整
xcrun simctl install booted \
  /Volumes/D/jev-ios-cache/Build/Products/Debug-iphonesimulator/JevJarvis.app
xcrun simctl launch booted com.jevchat.jarvis
```

键盘扩展（Keyboard Extension）需先在模拟器的「设置 → 键盘 → 添加新键盘」里启用，再切到 App 内测试。

---

## 5. 编译：真机（sideload / 开发签名）

```bash
./build.sh device        # Release + iphoneos，需提前在 Xcode 配好 Team
```

或裸命令（把 `YOUR_TEAM_ID` 换成你的开发者团队 ID）：

```bash
xcodebuild -project JevJarvis.xcodeproj \
  -scheme JevJarvis \
  -configuration Release \
  -sdk iphoneos \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -derivedDataPath /Volumes/D/jev-ios-cache/DerivedData \
  SYMROOT=/Volumes/D/jev-ios-cache/Build/Products \
  OBJROOT=/Volumes/D/jev-ios-cache/Build/Intermediates \
  SHARED_PRECOMPS_DIR=/Volumes/D/jev-ios-cache/Build/Precompiled
```

Xcode 首次真机运行会在 **Signing & Capabilities** 自动生成开发证书与 Provisioning Profile（免费账号可用，7 天有效期，需重签）。

---

## 6. 出 IPA（iOS 打包成品）

**一条命令（推荐）**：`build.sh ipa` 先归档再自动导出 IPA，缓存全部在 D 盘：

```bash
# 付费 $99 账号（App Group 键盘共享可用）：
JEV_TEAM_ID=你的团队ID ./build.sh ipa

# 免费 Apple ID（未付 $99，仅装自己设备测试）—— 自动去掉 App Group，主 App 可正常跑：
JEV_FREE_ACCOUNT=1 JEV_TEAM_ID=你的团队ID ./build.sh ipa

# 产物: /Volumes/D/jev-ios-cache/Build/IPA/JevJarvis.ipa
```

> ⚠️ **签名团队必须是你自己的**：`project.yml` 的 `DEVELOPMENT_TEAM` 由 `JEV_TEAM_ID` 环境变量驱动。解析优先级：
> 1. 显式 `export JEV_TEAM_ID=你的团队ID`；否则
> 2. **build.sh 自动从本机 Apple Development 证书的 `OU` 字段读出团队 ID**（苹果规定证书 OU 即团队 ID，免手抄）；否则
> 3. 回退上游占位 `75LZ93U5CF`。
>
> **如何拿到自己的 Team ID（免费账号）**：在本机 Xcode 中用 Apple ID 登录 → `Xcode ▸ Settings ▸ Accounts` 选中你的 Apple ID，右侧即显示 10 位 **Team ID**（你的账号会标为 “(Personal Team)”）。也可在 Mac Safari 登录 developer.apple.com ▸ Membership 查看。
>
> ❗ **注意别搞错**：iPhone「Apple Developer」App 里显示的 10 位「**注册 ID**」**不是**签名用的团队 ID（那是报名/账户注册标识）。真正的签名团队 ID 请以上面 Xcode 为准。免费账号**无需**在 App 内点「$98.99/年 订阅」。
>
> 💡 **免费账号**：加 `JEV_FREE_ACCOUNT=1` 即走免费路径，build.sh 改用 `App/JevJarvis.free.entitlements` / `Keyboard/JevKeyboard.free.entitlements`（不含 App Group），免费 Apple ID 也能签名装到自己手机。代价：主 App 与键盘扩展的共享配置不可用（`Shared/JevModel.swift` 会自动回退到本地 `UserDefaults.standard`，不崩）；付 $99 升级后去掉该变量即可恢复 App Group 共享，工程代码无需再改。

**手动分步**（自定义分发方式 `development` / `ad-hoc` / `app-store`）：

```bash
./build.sh archive       # 产出 .xcarchive 到 D 盘
xcodebuild -exportArchive \
  -archivePath /Volumes/D/jev-ios-cache/Build/JevJarvis.xcarchive \
  -exportPath /Volumes/D/jev-ios-cache/Build/IPA \
  -exportOptionsPlist ExportOptions.plist   # 自建，method 按分发方式填
```

> 真机 / App Group 说明：本项目 App 与键盘扩展共用 App Group `group.com.jevchat.jarvis`（用于共享配置与密钥）。**App Group 能力在免费账号下不可用**，需 $99 付费开发者账号才能在 Signing & Capabilities 中勾选并生效；否则键盘扩展无法读取 App 侧写入的共享数据。构建缓存与 DerivedData 不受影响，始终在 D 盘。

---

## 7. 校验：缓存确实在 D 盘、不在系统盘

```bash
# 构建缓存应在 D 盘
ls -d /Volumes/D/jev-ios-cache/DerivedData && echo "✅ DerivedData 在 D 盘"

# 系统盘（macOS 的 C 盘等价物）不应出现本项目的 DerivedData
ls ~/Library/Developer/Xcode/DerivedData 2>/dev/null | grep -i jev \
  && echo "⚠️ 发现 C 盘残留，检查 project.yml / build.sh" \
  || echo "✅ 系统盘无本项目 DerivedData"

# 运行时缓存（仅当 JEV_USE_DISK_CACHE=1 时启用磁盘缓存）
JEV_USE_DISK_CACHE=1 ./build.sh sim
ls -d /Volumes/D/jev-ios-cache/runtime && echo "✅ 运行时缓存在 D 盘"
```

> **设备端限制（已在 `docs/CACHE.md` 说明）**：真机运行时，App 沙盒内的 `Library/Caches` 与 App Group 存储**受 iOS 沙盒限制无法重定向到外部卷**，这部分仍落在设备本机。可重定向到 D 盘的是：Xcode 构建缓存（DerivedData / SYMROOT / OBJROOT / SHARED_PRECOMPS_DIR）以及 Mac 模拟器运行时缓存。代码已通过 `JevPaths` 显式设定路径并在 DEBUG 下打印，确保构建侧零写入系统盘。

---

## 8. 诊断日志

- DEBUG 构建启动时会在 Xcode 控制台打印 `JevPaths.dump()`（缓存根、各子目录绝对路径）。
- Mac 上会把诊断追加写入 `/Volumes/D/jev-ios-cache/logs/jev-diag.log`（真机因沙盒静默失败，符合预期）。

---

## 9. 常用命令速查

| 目的 | 命令 |
|------|------|
| 生成工程 | `xcodegen generate` |
| 模拟器编译+运行 | `./build.sh sim` |
| 真机编译 | `./build.sh device` |
| 归档出包 | `./build.sh archive` |
| 一键出 IPA（iOS 打包成品） | `JEV_TEAM_ID=你的团队ID ./build.sh ipa` |
| 一键出 IPA（免费账号，无 App Group） | `JEV_FREE_ACCOUNT=1 JEV_TEAM_ID=你的团队ID ./build.sh ipa` |
| 打印当前缓存路径配置 | `./build.sh paths` |
| 查看缓存目录占用 | `du -sh /Volumes/D/jev-ios-cache` |
