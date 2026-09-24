# jev-chat-jarvis（iOS · 键盘版）

聊天 App 收到一条消息 → 在**当前聊天 App 的键盘上**直接看到这句话的**意图、风险**和**候选回复**，点一下就进输入框。

不跳 App、不切后台、不申请录屏权限——**一个自定义键盘打通所有聊天软件**，这是它和桌面版「悬浮窗 + 抓屏」路线的根本区别，也是「全站」能力的地基。

## 与其他版本的路线差异

| | macOS / Windows | Android | 社区 iOS 录屏版（PR #24） | **本仓库（键盘版）** |
|---|---|---|---|---|
| 感知消息 | 抓窗口 + OCR | 无障碍树 | 录屏 + 视觉模型（4~15s） | **用户长按消息 → 复制**（剪贴板） |
| 展示候选 | 悬浮窗 | 悬浮窗 | 通知横幅 | **键盘面板**（就在输入框上方） |
| 填入回复 | 辅助功能/粘贴 | ACTION_SET_TEXT | 复制进剪贴板，自己切回去粘贴 | **insertText 直插输入框** |
| 每条消息操作 | 0 点击（全自动） | 0~1 点击 | 3+ 点击且要切 App | **4 点击且零切换** |
| App 适配 | 仅单一聊天 App，布局常量易失效 | 每 App 一个适配器 | 仅验过单一聊天 App | **零适配，任何 App 通用** |
| 权限 | 录屏 + 辅助功能 | 无障碍 + 悬浮窗 | 录屏（每次启动重新授权） | **仅「允许完全访问」一次** |

键盘版的取舍是诚实版：iOS 没有无障碍树、没有跨 App 悬浮窗、录屏授权不能持久，全自动感知在这条路上代价太高（社区实测端到端 8.7~16.5 秒）。键盘方案用「长按 → 复制」一步手动换来了**快（2~5 秒出全链结果）、稳（不依赖聊天 App 布局）、全站（任何输入框都能用）**。

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
- 意图集 / 风险量表 / 话术库 / 起草 prompt 与 macOS、Windows、Android 版**同一口径**（见下）

## 三端一致性

`Shared/` 是 App 与键盘共用的逻辑层，沿用 macOS 版口径；起草提示词已调整为通用聊天场景：

| 口径 | 来源 | iOS 对应 |
|---|---|---|
| 8 类意图 | `src/judge.py INTENTS` | `JevPrompts.swift INTENTS` |
| 风险量表 0-9 | `src/judge.py RISK_LEVELS` | `JevPrompts.swift RISK_LEVELS` |
| 行动建议 | `src/judge.py ACTION_MAP` | `JevPrompts.swift ACTION_MAP` |
| 10 种话术 | `src/styles.py BUILTIN` | `JevPrompts.swift BUILTIN_TONES` |
| 起草 prompt | `src/generate.py PROMPT_ONE` | `JevPrompts.swift PROMPT_ONE`（通用聊天场景） |
| 候选清洗 | `src/generate.py _parse` | `CandidateParser`（同顺序：编号→引号→风格前缀→引号） |
| Jev URL 拼接 | `src/generate.py #42 单一规则` | `JevJudge.requestURL` |
| 阶段预算 | 社区 iOS 版真机教训 | `JevHTTP.postJSON`（重试与超时不再相乘） |

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
├── Keyboard/Sources/      # UIKit 键盘扩展（内存 <60MB 约束下的纯系统控件）
└── tools/PromptCheck/     # 口径回归
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

1. **感知自动化**（打通社区录屏方案的优点）：主 App 走 ScreenCaptureKit（iOS 26+ 的 `UIBackgroundModes: screen-capture`）自动读屏分析，把候选写进 App Group，键盘面板**主动展示**已就绪的候选——键盘继续当展示+填入端，感知与填入解耦
2. 键盘内完整 QWERTY（免切换打字）
3. 群聊适配（`@` 前缀）、知识库（Android 版的联系人档案/常驻笔记）
4. 定时换签名 / TestFlight 分发

## 许可

MIT。候选只插入输入框，**永不自动发送**；只读你自己账号里你自己看到的内容。
