# Jev Jarvis Support

Contact: [Public email address for support requests]

## Frequently asked questions

**The keyboard is missing.** On iPhone, open Settings > General > Keyboard > Keyboards > Add New Keyboard, add Jev Keyboard, and use the globe key in a text field to switch to it. Secure text fields may allow only the system keyboard.

**No suggestions appear.** Enable Allow Full Access for Jev Keyboard in iOS Settings. On the app's Models tab, enter your own generation service URL, model, and API key, then tap Test Connection. Ask your provider about access limits and pricing.

**How do I use it?** Copy a message in a chat app, switch to the Jev keyboard, and tap Analyze Clipboard. Analyze Input Field processes text already entered in the field. Tapping a suggestion inserts it. The keyboard's Send key inserts a newline, which the host app may use to send the message.

**Why Allow Full Access?** This iOS switch permits the keyboard to call your configured model service, read the clipboard, and share app settings. The app does not continuously upload keystrokes; selected text is sent when you request analysis. You may disable Full Access or remove the keyboard in Settings at any time.

**How do I clear data?** Clear API keys and change provider URLs on the Models tab, and remove custom tones you no longer need. Removing the app and keyboard extension lets iOS handle local app data. Ask the relevant model provider about data it has already received.

For privacy questions, see the [Privacy Policy](PRIVACY_POLICY_EN.md) or email the address above. When reporting a bug, include your iOS and app versions, provider type, and reproduction steps; do not send API keys or real chat content.
