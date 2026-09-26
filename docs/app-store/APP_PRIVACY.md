# App Store Connect: App Privacy 填写依据

本文件是提交时的核对材料，不是可直接公开的隐私政策。Apple 要求申报应用及第三方合作方的实际数据做法；选择哪家模型服务、是否保留请求、是否用于训练，可能改变答案。最终以发布构建和所接入服务商的条款为准。

## 已确认的数据流

| 数据 | 触发与用途 | 去向 |
| --- | --- | --- |
| 用户复制或在输入框中输入的文字 | 点“分析剪贴板”“分析输入框文字”或应用内“运行分析”后，用于判断、起草和排序 | 用户配置的生成服务；如配置判断服务，也会发送到判断服务 |
| 候选回复和话术说明 | 生成、可选排序 | 配置的模型服务；结果在设备运行内存中显示 |
| API Key、服务地址、模型和自定义话术 | 保存配置、调用服务 | App Group `UserDefaults`；调用时 API Key 发给对应服务 |
| 连接测试文字 | 用户点“测试连接” | 对应配置的服务 |
| 模型列表请求 | 键盘开启且满足完全访问等条件时预热 | 生成服务；携带 API Key，不含聊天正文 |
| 键盘状态及语言设置 | 状态展示、两端同步 | 本机 App Group `UserDefaults` |

当前源码未集成广告、第三方分析或跟踪 SDK，也未看到开发者运营的聊天内容服务器。`URLSession` 使用 ephemeral 配置；判断结果在内存中短暂缓存。可配置 HTTP 地址，不能把全部网络流量描述成已加密。

## 建议在 App Store Connect 中核对的选项

1. **Data Collection**：不要直接选“No, we do not collect data”。虽然没有 Jev 自有服务器，分析文字和 API Key 会发给用户配置的服务。先核对 Apple 对“collection”的定义，以及预设/允许的服务商是否在实时请求之外保留数据，再填写。若服务商可留存或访问，通常需要申报。
2. **User Content**：复制的聊天内容可能落入 **Emails or Text Messages**，任意输入框文字、候选回复也可能需要 **Other User Content**。若符合 Apple 的“收集”定义，按实际数据类型申报，用途为 **App Functionality**；不要把所有文字一律归入“其他用户内容”。
3. **Identifiers > User ID / Other Data**：API Key 可能关联第三方服务账户。核对服务商如何识别账户、记录 IP 地址或请求，再判断是否还需要相应类别。不要把仅在本机的语言、状态和配置无条件申报为远程收集。
4. **Linked to the User**：不能仅凭 Jev 没有登录功能就选“不关联”。模型服务可能通过 API Key 将请求与其账户关联；向服务商确认后填写。
5. **Tracking**：当前实现没有跨 App 跟踪、广告标识符或广告 SDK；如发布构建确实如此，可选不用于跟踪。是否“关联”与是否“跟踪”是两个不同问题。
6. **Privacy Policy URL**：填写公开、无需登录、可在手机浏览器访问的 HTTPS 页面。中英文页面分别对应商店本地化；页面上必须有真实运营者、邮箱、生效日期与第三方服务说明。

本地存储并不能证明“未收集”；第三方服务由用户配置，也不自动免除披露。若以后内置模型、中转、遥测或账号体系，需重新核对本表与两份隐私政策。

## 上架前向服务商确认

- 请求正文、候选及 API Key 是否存储，保留多久，是否用于模型训练。
- 处理区域、跨境传输、日志与删除渠道。
- 审核专用密钥是否允许提供给 Apple 审核人员，能否限额和事后撤销。

参考：[Apple App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)、[App privacy questions in App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。
