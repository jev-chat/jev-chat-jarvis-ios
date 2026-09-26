# jev-chat-jarvis (iOS keyboard)

Jev is an iOS keyboard extension for drafting replies in any chat app. Copy a message, switch to Jev, and get its intent, risk, and reply suggestions without leaving the current app.

The app and keyboard support **Chinese and English**. Open the **Home** tab in Jev Jarvis and choose **Interface language**. The setting is shared with the keyboard extension through the App Group.

## Features

- Intent and risk analysis for copied messages or text already in the input field
- Two reply suggestions per selected tone, with optional ranking
- Custom tones and up to two active tone slots on iOS
- Suggestions are inserted into the input field; sending always remains manual
- OpenAI-compatible and Anthropic-compatible generation endpoints
- Optional TypeSafe Jev judge for intent, risk, and ranking
- No self-hosted server, message storage, or keystroke logging

## Setup

1. Open `JevJarvis.xcodeproj` in Xcode 15 or later.
2. Select your Apple Developer Team for both `JevJarvis` and `JevKeyboard`.
3. Build and run the app on an iPhone.
4. On the iPhone, open Settings → General → Keyboard → Keyboards → Add New Keyboard → Jev Keyboard.
5. Open Jev Keyboard in the keyboard list and enable **Allow Full Access**.
6. Open the **Models** tab, choose a provider preset, and enter your own API key. Jev does not provide a generation service or relay.
7. In any chat app, long-press a message, tap **Copy**, switch to Jev, and tap **Analyze Clipboard**.

## Language behavior

The selected language is stored in the shared App Group container. Changing it in the app updates the keyboard the next time it is rendered. The language also controls the drafting prompt and the intent and risk labels shown in the app and keyboard.

## Verification

Run the shared regression checks on macOS:

```bash
swiftc -o /tmp/jevcheck tools/PromptCheck/main.swift Shared/*.swift && /tmp/jevcheck
```

Build without signing:

```bash
xcodebuild -project JevJarvis.xcodeproj -scheme JevJarvis -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

See [README.md](README.md) for the Chinese documentation, project structure, privacy boundary, known limitations, and release notes.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Suggestions are inserted into the input field and are never sent automatically.
