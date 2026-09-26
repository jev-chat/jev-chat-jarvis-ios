# TestFlight 分发手册（借他人开发者账号版）

给想把 Jev Jarvis 键盘发给一批人试用、但账号不是自己名下付费账号的情况。按顺序读，第 1 步的答案会决定后面走哪条路。

---

## 0. 先搞清两件事

**TestFlight 必须付费会员。** 免费 Apple ID / Personal Team（比如现在工程里的 `XZWGHPX856`）**做不了 TestFlight**，只能自签装自己手机（7 天过期）。所以必须用朋友的付费账号。

**朋友的账号是「个人」还是「公司」，决定你能不能自己上传。** 这是整件事最大的分岔：

| | 个人账号（Individual） | 公司账号（Organization） |
|---|---|---|
| 能不能把你加成团队成员 | ❌ 只能加成「App Store Connect 用户」（上限 50 人） | ✅ 加成真正的团队成员 |
| 你的身份能访问证书 / 描述文件 | ❌ **不能**（只有 Account Holder 能） | ✅ 可以（需勾选 Certificates, Identifiers & Profiles） |
| 你能不能自己 archive + 上传 | ❌ **不能自助** | ✅ 完全自助 |

查法：朋友登录 [developer.apple.com/account](https://developer.apple.com/account) → 右上角选对 team → 往下拉到 **Membership details** → 看 **Enrolled as** 字段，写着 `Individual` 还是 `Organization`。

> 注意是一个反直觉点：即使朋友在 App Store Connect 里把你设成 **Admin**，个人账号下你依然拿不到证书权限。Admin ≠ 能上传。Apple 文档原文：「If you're enrolled in the Apple Developer Program as an individual, you can give up to 50 additional users access to your content in App Store Connect. These users only access App Store Connect—they're not part of your team and won't receive other membership benefits.」

---

## 1. 上架前工程必须补的缺口

工程现状（`project.yml` / 仓库扫描，2026-09-23）：这几项**不补就传不上去，或者传上去会把不该公开的东西公开**。

### 1.1 图标 —— ✅ 已补（2026-09-23）

`App/Assets.xcassets/AppIcon.appiconset` 已就位：iPhone 全部尺寸 + 一张 **1024×1024** 的 App Store 槽位；`project.yml` 里 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 与新的 `App/Assets.xcassets` source 都已生效（改 `project.yml` 后记得 `xcodegen generate`）。

图标沿用 macOS 版设计（绿色底色 + 白色 J + 气泡尾巴），由 `tools/MakeAppIcon/main.swift` 画出：

```bash
swiftc -O -o /tmp/makeappicon tools/MakeAppIcon/main.swift && /tmp/makeappicon App/Assets.xcassets/AppIcon.appiconset
```

两处与 macOS 版刻意不同：**满出血**（不留圆角，iOS 自己切）和**无 alpha 通道**（带 alpha 吃 ITMS-90717，桌面上透明区也会画成黑色）。换设计改脚本重跑，别手改 PNG。键盘扩展不强制要图标，系统「键盘」列表里显示的是宿主 App 的图标。

### 1.2 隐私清单 `PrivacyInfo.xcprivacy` —— 缺了会收到 ITMS-91053 邮件

工程用了 `UserDefaults(suiteName: appGroupID)`（`Shared/JevModel.swift`），属于 Apple 的「required reason API」。自 2024-05-01 起新提交必须在隐私清单里声明理由。

**两个 target 各要一份**（App 和键盘扩展都用到了 App Group 的 UserDefaults）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

放进去后同样要在 `project.yml` 的 sources 里显式带上（xcodegen 生成工程时容易漏，`ITMS-91053` 的常见原因就是清单没进 Copy Bundle Resources）。

> 另外：用户主动点「分析」后，键盘会把剪贴板文本发到用户配置的模型服务。请按实际数据流填写 `NSPrivacyCollectedDataTypes`（可评估 `NSPrivacyCollectedDataTypeOtherUserContent`，用途 App Functionality），并在审核说明里讲清楚触发方式和服务提供方。

### 1.3 历史上提交过的 API Key —— 必须撤销轮换

项目曾把真实 API Key 硬编码进源码，并提交到了 Git 历史（commit `5b425a4`）。虽然当前代码已移除内置凭据和中转回退，删除源码不会清除历史记录；应将旧 Key 视为已泄露并在对应服务商后台撤销、轮换。不要把新 Key 写进 App 源码或仓库，用户应在 App 的模型设置中自行填写。

### 1.4 `NSAllowsArbitraryLoads = true` 与 HTTP 服务

两个 target 的 Info.plist 都开了 `NSAllowsArbitraryLoads`，主要用于兼容用户自行配置的本地 Ollama 等 HTTP 服务。项目不再提供中转服务；正式使用优先配置 HTTPS 模型端点。键盘只在用户主动分析时发送选中的消息内容，审核备注应准确说明数据接收方和传输方式（Guidelines 4.4.1 要求键盘安全传输数据）。

若发布版本不需要 HTTP 端点，收紧 ATS 例外并确认本地服务预设仍符合预期。

### 1.5 版本号 / 设备族 / scheme

- `CURRENT_PROJECT_VERSION` 每次上传必须**递增**，否则报「bundle version must be higher than the previously uploaded version」。键盘扩展和主 App 用同一个 `$(CURRENT_PROJECT_VERSION)`，这点已经是对的（Apple 要求 extension 版本与宿主一致），别改成各写各的。
- `TARGETED_DEVICE_FAMILY` 有冲突：project 级是 `1`（仅 iPhone），但 target 级被覆盖成 `"1,2"`（含 iPad），产物实测 `UIDeviceFamily = [1, 2]`。键盘扩展按规矩必须和宿主 App 设备族一致。**只发 iPhone 就在 `project.yml` 里显式统一成 `1`**，别靠默认值。
- 命令行归档需要 shared scheme，`JevJarvis.xcodeproj/xcshareddata/` 现在是空的。跑一次 `xcodegen generate` 生成，或在 Xcode 里 Plan → Shared 勾上。

**上传前的三分钟核对**（键盘 plist 出过两次事故，别再踩）：

```bash
cd /Users/leon/Documents/Justforfun/jev-chat-jarvis-ios
xcodegen generate
xcodebuild -project JevJarvis.xcodeproj -scheme JevJarvis \
  -destination 'generic/platform=iOS' -configuration Release \
  -archivePath /tmp/JevJarvis.xcarchive archive
# 核对产物 plist —— PrimaryLanguage 和 RequestsOpenAccess 少一个都会出事
plutil -p /tmp/JevJarvis.xcarchive/Products/Applications/JevJarvis.app/PlugIns/JevKeyboard.appex/Info.plist \
  | grep -E 'RequestsOpenAccess|PrimaryLanguage|NSExtensionPointIdentifier'
```

两者必须在 `NSExtensionAttributes` 里：`RequestsOpenAccess` 缺了 → 设置里根本不显示「允许完全访问」开关；`PrimaryLanguage` 缺了 → 键盘弹起时宿主 App 直接闪退。

---

## 2. 账号侧的一次性配置

以下的「门户」= developer.apple.com/account，「ASC」= appstoreconnect.apple.com。

| 步骤 | 谁做 | 说明 |
|---|---|---|
| 1. 注册 App ID | 个人账号只有朋友能做 | 门户 → Identifiers → 新建 App ID，Bundle ID 用 **explicit** `com.jevchat.jarvis`，并为键盘扩展注册 `com.jevchat.jarvis.keyboard` |
| 2. 注册 App Group | 同上 | 门户 → Identifiers → App Groups → 注册或选用 `group.com.jevchat.jarvis`，**同时授权给 App 和键盘扩展两个 App ID**（漏这步签名会报 entitlement 不匹配） |
| 3. 建 App 记录 | 朋友或你的 App Manager 角色 | ASC → My Apps → **+** → New App。Platform iOS / Name `Jev Jarvis` / Primary Language 简体中文 / Bundle ID 选第 1 步那个 / SKU 随便填唯一串 |
| 4. 把你加成 ASC 用户 | 朋友 | ASC → Users and Access → **+**。角色给 **App Manager**（够用）或 **Admin**。邀请链接 3 天过期 |
| 5. （个人账号走这条）生成 Team API Key | 朋友 | ASC → Users and Access → **Integrations** → App Store Connect API → **Team Keys** → **+**。下载 `.p8`（**只能下一次**），记下 Key ID 和 Issuer ID |

---

## 3. 上传构建 —— 按账号类型选一条

改 `project.yml` 里的 `DEVELOPMENT_TEAM` 为朋友账号的 Team ID，然后 `xcodegen generate`。

### 路径 A：朋友是公司账号（推荐，你全自助）

朋友在 ASC → Users and Access → 你的名字 → 勾上 **Certificates, Identifiers & Profiles**。然后你用**自己的 Apple ID** 登 Xcode（不是朋友的），Archive → Distribute App → App Store Connect → Upload。Xcode 会自动创建分发证书和描述文件，你全程不需要朋友的密码。

### 路径 B：朋友是个人账号（你无法自助，三选一）

按推荐度排序：

1. **朋友上传，你只给归档包**（最干净，零密码共享）
   你本机 archive 出 `/tmp/JevJarvis.xcarchive`，打包发给他，他在自己 Mac 上用 Xcode 的 Organizer → Distribute App 上传。代价是每次发版都要他配合几分钟。

2. **朋友给你分发证书 + 描述文件**
   他导出 `.p12`（带密码）+ App Store 描述文件给你，你本机装上后就能自己传。可行，但证书共享意味着双方都能滥用，属于信任成本 —— 适合关系很近的情况。

3. **用第 2 节第 5 步的 Team API Key 走云签名**
   ```bash
   xcodebuild -exportArchive \
     -archivePath /tmp/JevJarvis.xcarchive \
     -exportOptionsPlist ExportOptions.plist \
     -exportPath /tmp/export \
     -allowProvisioningUpdates \
     -authenticationKeyPath ~/AuthKey_XXXX.p8 \
     -authenticationKeyID <Key ID> \
     -authenticationKeyIssuerID <Issuer ID>
   ```
   `ExportOptions.plist` 里 `destination` 写 `upload`，且**不要**写 `signingCertificate` / `provisioningProfiles` 两个键（写了但本机没有对应 profile 会直接失败）。
   > ⚠️ 这条路有不确定性：API Key 只支持 `-exportArchive` 不支持 archive 步骤（先无 key 归档，再用 key 导出上传），且有开发者反馈「个人账号 + 非 Account Holder」时仍会报 `Code=-19000 Failure to authenticate`。**先花 10 分钟试一下**，不通就退回路径 B-1。

### 路径 C：不推荐
朋友圈共享 Apple ID 密码。技术上能跑，但对方账号的邮件、支付、隐私全部暴露，且违反 Apple 的账号条款，别用。

上传成功后会收到邮件，处理 5~30 分钟（偶尔更久），ASC 的 TestFlight 标签页看到构建状态变 Ready 就能加测试者。

---

## 4. TestFlight 里怎么配、怎么给链接

### 先明确：TestFlight **不给安装包**

没有 `.ipa` 可发，没有下载链接可直接装。全流程是这样的：

```
测试者 → 从 App Store 装「TestFlight」App → 点你的链接 / 输兑换码
      → 在 TestFlight 里点 Install → 装到手机上 → 照常从设置启用键盘
```

### 内部测试 —— 最快，不用审核，先走这个

- 对象：ASC 用户（就是你，以及朋友），**上限 100 人**
- **不需要 Beta App Review**，构建处理完就能装
- 加人：ASC → TestFlight → Internal Testing → 建组 → 加 ASC 用户
- 用途：你和朋友先自测一遍，确认键盘在别人手机上也能正常启用，再考虑对外

> 个人账号下你虽然是「ASC 用户不是团队成员」，但当内部测试者完全没问题 —— 这是个人账号下你能拿到的最快反馈通道。

### 外部测试 —— 给别人用，要先过审

- 上限 **10000 人**，测试者只需要 Apple ID + TestFlight App，**不需要** ASC 账号
- **每个新版本（marketing version）的第一个 build 必须过 Beta App Review**，通常 24~48 小时（快的话几小时）；同一个版本后续 build 免审直接可用
- 24 小时内最多提交 6 个 build 送审
- 两个加人方式：
  - **邮箱邀请**：加具体邮箱，上限 100 个
  - **公开链接**（给别人最省事的方式）：建好外部测试组 → **Enable Public Link** → 拿到形如 `https://testflight.apple.com/join/XXXXXXXX` 的链接，往群里一丢就行
    - 可选「Open to Anyone」或按设备 / 系统版本过滤
    - 可设人数上限（1~10000）
    - 链接在「你手动关闭 / 到达上限 / build 过期」前一直有效
    - 代价：谁拿到链接谁都能装，控制不了

### 提交外部测试前必须填的 Test Information

- **Beta App Description**（这个 App 是干嘛的）
- **Feedback Email**（测试者反馈收件箱）
- **Privacy Policy URL**（必填）
- **What to Test**（建议写，不然测试者不知道点哪）
- 如果 App 需要登录才可用，要给审核员一个演示账号 —— 我们因为有内置兜底、开箱能出候选，**不需要**提供 Key，这是内置兜底的价值之一

### Build 90 天过期（容易忘）

上传后 **90 天**，build 到期，测试者手机上的 App **直接打不开**，本地数据（登录态、缓存）一起没。要在到期前传一个 `CURRENT_PROJECT_VERSION` 递增的新 build。**给外部测试者用的话，把「每 2 个月发一次版」排进日程**，否则某天所有人同时用不了。

---

## 5. 给测试者的说明（直接复制发出去）

> **装 Jev 键盘试用版**
>
> 1. 先在 App Store 装 **TestFlight**（苹果官方的测试工具）
> 2. 用 iPhone 点开这个链接：`https://testflight.apple.com/join/XXXXXXXX`
> 3. 在 TestFlight 里点「安装」，装好后**先打开一次 Jev Jarvis**（不打开的话下一步在设置里找不到键盘）
> 4. 设置 → 通用 → 键盘 → 键盘 → **添加新键盘** → 选「**Jev 键盘**」
> 5. 回到键盘列表，点「**Jev 键盘**」→ 打开「**允许完全访问**」→ 弹窗点「允许」
>    - 这个开关是必须的：键盘要联网才能生成候选回复，也要读剪贴板拿到你要分析的那条消息。系统弹窗的措辞看着吓人（"开发者可能访问你输入的内容"），实际只会把**你主动点「分析剪贴板」时**的那条消息发去生成回复。
> 6. 在任意聊天窗口长按一条消息 → 复制 → 切到 Jev 键盘（长按左下角地球键）→ 点「分析剪贴板」
> 7. 候选出来点一下就插进输入框；点「发送」试它认不认换行（有的 App 不认）
>
> 有效期 90 天，到期我会发新的，重装一下就好。

---

## 6. 坑清单（都是会真的踩到的）

| 现象 | 原因 | 处理 |
|---|---|---|
| 上传报 `ITMS-91111` / `ITMS-90704` | 缺 1024×1024 图标 | 见 1.1（已补，若复发检查那张 1024 是否还在） |
| 上传后收到 `ITMS-91053` 邮件 | 缺隐私清单，或清单没进 Copy Bundle Resources | 见 1.2 |
| `The bundle version must be higher than...` | build number 没递增 | 改 `CURRENT_PROJECT_VERSION` |
| 设置里找不到「允许完全访问」开关 | `RequestsOpenAccess` 放错层级（必须在 `NSExtension` → `NSExtensionAttributes` 里） | 改 `project.yml` 后 `xcodegen generate` |
| 点输入框、键盘弹起时宿主 App 闪退 | `NSExtensionAttributes` 缺 `PrimaryLanguage` | 同上；崩溃签名是 `TIGetDefaultDictationLanguagesForKeyboardLanguage` |
| 设置里看不到 Jev 键盘 | 装完没打开过宿主 App | 让测试者先启动一次 App |
| 签名报 entitlement 不匹配 | App Group 建了但没勾进 App ID | 回门户把 App Group 关联到 App ID |
| 外部测试者点链接提示不可用 | 第一个 build 还在 Beta App Review / 已过 90 天 | 看 ASC 的 TestFlight 状态 |
| 被审核拒 | 用户配置的 HTTP 端点传输聊天内容（4.4.1 「Transmit securely」） | 优先使用 HTTPS，并准确填写审核说明，见 1.4 |

---

## 7. 一句话总结

**别指望「直接用他的账号」** —— 先花一分钟确认他是 `Individual` 还是 `Organization`：公司账号给你 Admin + 证书权限，你就是全自助；个人账号则**只有他本人能上传**，你需要选「他代传归档包」或「他给你分发证书」二者之一。至于把 App 给出去，TestFlight 的模式是**发一个 `testflight.apple.com/join/xxx` 公开链接**，对方装 TestFlight App 点链接安装，**不存在发安装包这条路**；而键盘必须由测试者手动在设置里启用并打开「允许完全访问」，这段操作要写进你发给测试者的说明里（第 5 节可直接复制）。
