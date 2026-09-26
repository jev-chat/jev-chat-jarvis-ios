# iOS 上架资料与发布核对表

项目目前尚未达到可直接提交审核的状态。本页把已准备的材料、待填写字段和需要实际修复的工程问题放在一起。`[ ]` 表示发布前必须逐项确认，并非已通过的声明。

## 已准备的文件

| 用途 | 文件 |
| --- | --- |
| 简体中文 / 英文隐私政策 | `PRIVACY_POLICY_ZH.md` / `PRIVACY_POLICY_EN.md` |
| 简体中文 / 英文支持页 | `SUPPORT_ZH.md` / `SUPPORT_EN.md` |
| 简体中文 / 英文商店文案 | `STORE_LISTING_ZH.md` / `STORE_LISTING_EN.md` |
| App Privacy 填写依据 | `APP_PRIVACY.md` |
| 审核说明 | `REVIEW_NOTES_EN.md` |
| 6.9 英寸 iPhone 中英文截图 | `../../marketing/app-store-upload/zh-Hans/` / `../../marketing/app-store-upload/en/` |

应用预览视频不是必填；现有 PNG 是截图，不是 App Preview。文案、截图和审核步骤要与最终上传的构建一致。

## 需要运营者填写与发布

- [ ] 将上架主体的真实姓名或公司全称、公开隐私/支持邮箱填入中英文隐私政策和支持页；邮箱需能实际收信。
- [ ] 把中英文隐私政策、支持页发布为无需登录的 HTTPS 页面，在手机浏览器中实测可访问；将对应 URL 填入 App Store Connect 的 Privacy Policy URL 和 Support URL。GitHub 仓库中的未发布本地文件不能作为 URL。
- [ ] 在应用内提供可访问的隐私政策入口，并在开启“允许完全访问”和发送内容到第三方模型服务前清楚说明接收方及用途。
- [ ] 对照实际接入的服务商核对 `APP_PRIVACY.md`，填完 App Store Connect 的隐私问卷；不要直接选择“未收集数据”。
- [ ] 在 App Store Connect 填简体中文和英文名称、副标题、描述、关键词及新版本内容；核对商标、版权、分类、年龄分级、价格和销售地区。SKU 已在创建 App 记录时确定，无须展示给用户。
- [ ] 确认使用 Apple 标准最终用户许可协议，或另外准备并填写自定义 EULA URL；不需要因为上架而默认另写一份用户协议。
- [ ] 上传 `marketing/app-store-upload/zh-Hans/` 与 `en/` 下各三张 1320 x 2868 的 iPhone 截图，逐张确认真实 UI 与当前构建一致、无真实聊天或密钥；如最终构建支持 iPad，还需对应 iPad 截图。
- [ ] 在审核备注中提供可用的限额测试服务和密钥，说明操作步骤与数据流；密钥只填 App Store Connect，不能写进仓库或截图。

## 工程与审核阻断项

- [ ] **App Group 授权与共享**：`project.yml`、`Shared/JevModel.swift` 和 App/Keyboard 的 `.entitlements` 已统一使用 `group.com.jevchat.jarvis`。确认 Apple Developer 后台已将该组授权给两个 App ID，使用更新的描述文件签名，并在真机验证共享设置。Team 当前设为 `75LZ93U5CF`，Bundle ID 为 `com.jevchat.jarvis`，键盘扩展为 `com.jevchat.jarvis.keyboard`。
- [ ] **隐私清单**：当前两个 target 都未见 `PrivacyInfo.xcprivacy`。按 Apple 最新 required-reason API 规则，为使用 App Group `UserDefaults` 的 App 和键盘扩展加入对应清单，确认适用的 approved reason 与实际用途一致，并检查归档产物内各自包含清单。App Privacy 问卷与清单的“收集数据”项应相互一致。
- [ ] **第三方键盘审核**：按 [App Review Guidelines 4.4.1](https://developer.apple.com/app-store/review/guidelines/) 复核键盘的基本输入能力及关闭 Full Access 后的可用性。当前键盘是回复面板，未提供完整打字键盘，且关闭 Full Access 时进入门禁页，存在审核风险；提交前需实测并处理。
- [ ] **HTTP 与数据传输**：两个 target 的 `NSAllowsArbitraryLoads` 为 `true`，用户可配置 HTTP 模型端点。确认发布范围是否需要此能力，评估 App Review 对键盘传输的要求；隐私文案和审核说明不能笼统承诺全部请求经过 HTTPS。
- [ ] **调试与密钥**：归档 Release 构建；Debug 诊断代码会把输入框末尾文字写入本机 App Group。历史上进入 Git 的旧 API Key 需在对应服务商后台撤销并轮换。
- [ ] **设备族与签名**：两个 target 已在 `project.yml` 和 `JevJarvis.xcodeproj` 中显式设为 iPhone 设备族 `1`。归档后核对 App 和键盘扩展的 `UIDeviceFamily` 均为 `[1]`，并确认两个 target 使用相同 Team、正确 App Group 和可用的分发签名。若以后启用 iPad，还需补齐 iPad 图标、支持方向和截图。

## 构建与提交

- [ ] 运行 `xcodegen generate`（若修改 `project.yml`），构建 App 和扩展，并在真机测试安装、完全访问、剪贴板、候选插入及宿主应用中的换行行为。
- [ ] 运行 `swiftc -o /tmp/jevcheck tools/PromptCheck/main.swift Shared/*.swift && /tmp/jevcheck`；对照中英文截图检查本地化。
- [ ] 递增 `CURRENT_PROJECT_VERSION`；确认版本、导出合规性（当前 plist 声明 `ITSAppUsesNonExemptEncryption = false`）、内容版权及地区要求。若实际加密用途或法规义务变化，重新填写。
- [ ] Archive、Validate App、上传构建，完成 App Store Connect 的年龄分级、隐私和审核资料，再提交审核。

Apple 提交规则会变化，以 [App Store Connect Help](https://developer.apple.com/help/app-store-connect/) 和当前后台字段为准。
