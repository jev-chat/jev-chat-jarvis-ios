# jev-chat-jarvis（iOS · 键盘版）

聊天 App 收到一条消息 → 在**当前聊天 App 的键盘上**直接看到这句话的**意图、风险**和**候选回复**，点一下就进输入框。

不跳 App、不切后台、不申请录屏权限——**一个自定义键盘打通所有聊天软件**，任何输入框都能用。

<p align="center">
  <img src="docs/demo.gif" alt="键盘实际演示：长按复制对方消息 → 键盘上出意图/风险/候选 → 点按插入输入框" width="320">&nbsp;&nbsp;
  <img src="docs/setup.gif" alt="App 设置演示：键盘状态自检、三步启用、内置话术库" width="320">
</p>

## 反馈与帮助

**合作、反馈、进群，请公众号私信**：

<table>
  <tr>
    <td align="center"><img src="docs/wechat-mp-qr.png" width="200" alt="扫码关注公众号"><br><sub>公众号</sub></td>
  </tr>
</table>

## 用法

### 1. 装到 iPhone

1. Mac 上双击打开 `JevJarvis.xcodeproj`（需 Xcode 15+，本工程用 Xcode 27 验证编译）
2. Xcode 左上角选 target **JevJarvis** → Signing & Capabilities → Team 选你的 Apple ID（免费个人账号即可；Xcode → Settings → Accounts 可添加）
3. 插上 iPhone，选它作为运行目标，`Cmd+R`。首次运行在手机上：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书
4. 两个 target（App 和 JevKeyboard）都要选**同一个 Team**，否则 App Group 共享不通

> 免费个人账号签名 7 天过期，到期重新 `Cmd+R` 一次即可。

### 2. 启用键盘（手机上操作）

1. 设置 → 通用 → 键盘 → 键盘 → **添加新键盘** → 选「Jev 键盘」
2. 回到键盘列表，点「Jev 键盘」→ 打开 **允许完全访问**（联网 + 读剪贴板必须）
3. 打开 Jev Jarvis App →「模型」页：选个预设（智谱 `glm-4-flash` 免费 / DeepSeek 最快 / OpenRouter 一个 key 全模型），填 Key，点「测试连接」
4. 到「试一试」页跑一条消息，通了就是全通了

### 3. 在聊天 App 中使用

1. 长按对方那条消息 → **复制**
2. 输入框获得焦点，键盘切到 Jev（地球键切换）→ 点 **「分析剪贴板」**
3. 键盘上显示：意图 + 风险 0-9 + 行动建议 + 每话术 2 条候选（前稳后放）
4. 点中意的候选 → 文字直接进入当前输入框 → **发送由你手动完成**（本项目永不自动发送）

另有「分析输入框文字」按钮：分析你打到一半拿不准的话（读 `documentContextBeforeInput`）。

## 配置

全部在 App 内完成，改完即存、键盘即时生效（无需重启）：

- **生成层（必配）**：OpenAI 兼容（`/chat/completions`）或 Anthropic 兼容（`/v1/messages`）任一端点。地址带不带 `/v1`、填到动作段都能拼对。支持额外字段 JSON（默认带 `enable_thinking:false`，Qwen3 类模型必须关思考）。**别用思考型模型**，思考占满额度会 0 条候选（错误信息里会直接点名）。
- **判断层（核心）**：TypeSafe Jev（systemone 接口），一次调用同时出 8 类意图概率分布 + 0-9 风险分布，并给候选排序；界面内置 TypeSafe 直连 / OpenRouter / Vercel AI Gateway 三个预设，网关地址、模型、key 全部可自定义。没配 key 时运行时自动退化为「盲起草」（只出候选），这不是配置开关而是兜底。地址带不带 `/v1`、填到动作段都能拼对。
- **话术**：3 个槽位，内置 10 种话术（高情商 / 贴吧老哥 / 拒绝加班 / 卑微乙方 / 稳如老狗 / 已读乱回 / 鱼塘主 / 职场黑话 / 阴阳怪气 / 理科直男），支持自定义（说明写「什么语气 + 别变成什么」最管用）。每话术一次请求、出 2 条，多话术并发。

### 隐私边界

- 聊天内容只在点「分析」那一刻发往**你自己配置**的模型接口；无自建服务器、不落盘、不进日志
- API Key 存本机 App Group 私有容器，仅 App 与键盘可读
- 键盘不监听、不上传按键；「允许完全访问」随时可在系统设置里关闭或移除键盘

## 口径回归

`Shared/` 目录是 App 与键盘共用的单一口径层：意图集、风险量表、行动建议、话术库、起草 prompt、候选清洗和 URL 拼接规则都只在这一份实现里，两端行为一致。起草 prompt 面向通用聊天场景。

口径回归（Mac 上直接跑，不需要 iPhone）：

```bash
swiftc -o /tmp/jevcheck tools/PromptCheck/main.swift Shared/*.swift && /tmp/jevcheck
```

## 工程结构

```
├── project.yml            # xcodegen 工程定义（改完跑 `xcodegen generate`）
├── Shared/                # App 与键盘共用的单一口径层（仅 Foundation，无 UI）
│   ├── JevModel.swift     # 配置模型 + App Group 存储
│   ├── JevPrompts.swift   # 意图/风险/话术/prompt/清洗
│   ├── JevHTTP.swift      # 带总预算的 POST（429/5xx 退避重试）
│   ├── JevJudge.swift     # TypeSafe systemone：判断 + 排序
│   ├── JevDraft.swift     # OpenAI/Anthropic 起草
│   └── JevPipeline.swift  # 判断 → 每话术并发起草 → 排序
├── App/Sources/           # SwiftUI：开始（键盘状态）/ 模型 / 话术 / 试一试
├── App/Assets.xcassets/   # AppIcon（改设计见 tools/MakeAppIcon，别手改 PNG）
├── Keyboard/Sources/      # UIKit 键盘扩展（内存 <60MB 约束下的纯系统控件）
└── tools/
    ├── PromptCheck/       # 口径回归
    └── MakeAppIcon/       # 画 AppIcon：swiftc -O -o /tmp/makeappicon tools/MakeAppIcon/main.swift && /tmp/makeappicon App/Assets.xcassets/AppIcon.appiconset
```

编译自检（不需要证书）：

```bash
xcodegen generate
xcodebuild -project JevJarvis.xcodeproj -target JevJarvis -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 已知限制

- **复制的消息不含上下文**：剪贴板里通常只有那一条。如果聊天 App 支持复制引用内容，可借此带上被引文字；多轮上下文见路线图
- 键盘高度固定 320pt，候选多时可滚动；横屏未适配
- App Group 需两个 target 同一 Team 签名；免费个人账号一般可用，个别情况下需付费账号
- 密码框等安全输入会强制系统键盘（系统行为，不是 bug）
- 免费账号签的键盘 7 天过期需重装

## 路线图

1. **感知自动化**：主 App 走 ScreenCaptureKit（iOS 26+ 的 `UIBackgroundModes: screen-capture`）自动读屏分析，把候选写进 App Group，键盘面板**主动展示**已就绪的候选——键盘继续当展示+填入端，感知与填入解耦
2. 键盘内完整 QWERTY（免切换打字）
3. 群聊适配（`@` 前缀）、知识库（联系人档案/常驻笔记）
4. 定时换签名 / TestFlight 分发 —— 借他人开发者账号的完整流程见 [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md)

## 许可

Copyright © 2026 eatmoreduck 与 jev-chat 贡献者。代码以 [MIT](LICENSE) 协议开源，另见 [NOTICE](NOTICE)。

- **可以商用**：个人和公司都可以使用、修改、再分发，不需要付费或事先授权。
- **必须注明出处**：分发或商用时保留 `LICENSE` 与 `NOTICE`，并写明来源。
- **不要用**「秒回」「Jev 聊天助手」「jev-chat」「jev-jarvis-ios」名称暗示由原作者出品或背书。
- **仅供正当用途**：本项目只辅助你自己真诚的日常沟通。严禁用于任何违法违规行为，**包括但不限于任何形式的诈骗（杀猪盘、养老诈骗、婚恋诈骗）、冒充他人、骚扰、垃圾营销**。
- **免责声明**：本项目按「现状」提供，作者不参与、不知情、也不为任何使用者的具体使用行为负责，由此产生的一切后果与法律责任由使用者自行承担。本项目只处理你自己设备上、你自己有权查看的聊天，候选只插入输入框，**永不自动发送**。
- 完整风险告知见置顶 issue：[使用声明与风险告知](https://github.com/jev-chat/jev-chat-jarvis-ios/issues/2)。
