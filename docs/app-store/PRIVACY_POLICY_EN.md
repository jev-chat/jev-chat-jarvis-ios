# Jev Jarvis Privacy Policy

Effective date: September 26, 2026

Operator: [Legal name of the individual or company publishing the app]

Privacy contact: [Public email address for privacy requests]

This policy covers the Jev Jarvis iOS app and its keyboard extension. We will update it when the app's behavior, model providers, or data practices change.

## 1. Information processed

- **Text you choose to analyze.** When you tap Analyze Clipboard, analyze text in the input field, or run an analysis in the app, the app reads that text to assess intent and risk and to draft and rank reply suggestions. It may include chat messages or other text you entered. The app does not continuously monitor keystrokes for reply generation or read the clipboard until you request clipboard analysis.
- **Model settings and API keys.** Your service URLs, model choices, API keys, additional request fields, custom tones, and language choice are stored in the app's configuration on your device and shared between the app and keyboard extension. API keys are not sent to a Jev Jarvis-operated server. They are sent as credentials to the services you configure. The current implementation stores settings in local App Group `UserDefaults`, rather than a separate Keychain item.
- **Keyboard status.** The time the keyboard was last opened and whether Full Access is enabled are stored on the device so the app can show setup status. The app does not create a user account for this purpose.
- **Temporary results.** The current message, suggestions, and analysis results are used in process memory. A judgment for the same message may be cached in memory for about five minutes to speed up repeat analysis. The app has no developer-operated server for storing chat text.

## 2. Network requests and recipients

You choose a generation service and may separately configure an optional judgment and ranking service. When you request analysis, the app may send the selected text, tone instructions needed to draft a reply, and candidate replies to those configured services. Test Connection sends built-in sample text to the relevant service. If Full Access is enabled and a generation service is configured, opening the keyboard may also request the service's model list to warm up the connection; this sends the API key but no chat text.

Your selected services may be third-party AI providers, gateways, or local services. A provider may receive the request content, API key, IP address, and connection information, and may process, retain, or transfer that information under its own policies. Read the provider's privacy policy and terms before entering a key. Jev Jarvis cannot control a provider's retention period, model-training settings, or processing location. The app permits user-configured HTTP endpoints; HTTP traffic may be unencrypted. Prefer HTTPS and avoid sending sensitive content to untrusted endpoints.

## 3. Clipboard, keyboard, and Full Access

iOS Full Access allows a third-party keyboard to use the network, clipboard, and shared app settings. Granting it does not by itself cause continuous upload of typed text. You may disable Full Access or remove the Jev keyboard at any time in iOS Settings > General > Keyboard > Keyboards. Network and clipboard features will then be unavailable.

Tapping a suggestion inserts it into the current input field. The keyboard's Send button inserts a newline; the host chat app determines whether that newline sends the message. Jev Jarvis does not send messages without a user action.

## 4. Purpose, sharing, and retention

The information above is used to provide the analysis, drafting, ranking, connection test, keyboard status, and local settings synchronization you request. The current version has no advertising or analytics SDK and does not use this information for cross-app tracking or sell personal information.

Local settings remain until changed or the app is removed. In-memory analysis data is cleared when the process ends; judgment cache entries expire after about five minutes. Retention by a provider you choose is governed by that provider. The app cannot delete data already received by a provider. Production builds do not log chat text; development builds may write diagnostic information.

## 5. Your choices and deletion requests

You may choose not to enable the keyboard or Full Access, leave provider credentials blank, or stop using analysis at any time. You can change provider URLs and clear API keys and custom tones in the app. After you remove the app and keyboard extension, iOS handles deletion of local app data. Contact the privacy address above about this app's data practices or deletion requests. Contact the relevant provider as well for data it may have retained.

## 6. Children and changes

The app is not designed for children. Do not process messages you are not authorized to use, or submit sensitive personal information without understanding the selected provider's practices. Material changes will be reflected on the public policy page with a new effective date, and material changes to in-app data practices should also be disclosed in the app.
