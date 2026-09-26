# App Review notes (paste into App Store Connect)

This file is a template. Complete the review-only provider credentials directly in App Store Connect. Never commit API keys to this repository.

## Notes for reviewer

Jev Jarvis is a third-party keyboard extension that drafts replies to text the user chooses to analyze. It has no Jev account or sign-in. The user supplies a model service; to make the core feature reviewable, we provide temporary test credentials below.

To test the app:

1. Open Jev Jarvis > Models. Set the generation service URL, API format, model, and API key from the review credentials. Tap Test Connection. The optional judge service provides intent, risk, and ranking; without it, reply drafting still works.
2. Open Settings > General > Keyboard > Keyboards > Add New Keyboard > Jev Keyboard. Select Jev Keyboard and enable Allow Full Access. The extension needs this setting to reach the configured model service and read the clipboard.
3. In Notes or another ordinary text field, type a sample message such as “Can we meet tomorrow morning?”, select and copy it, switch to Jev Keyboard with the globe key, then tap Analyze Clipboard. Tap a suggestion to insert it. Alternatively, type text in the field and tap Analyze Input Field.
4. The Send key inserts a newline. The host app decides whether a newline sends a message. No message is sent without a user action.

The keyboard reads clipboard text only after Analyze Clipboard is tapped. The selected text, tone instructions, and generated suggestions may be sent to the configured generation and optional judge services. A model-list warm-up request may occur when the keyboard opens; it contains the API key but no chat content. There is no Jev-operated relay. Provider privacy practices are described in the linked privacy policy.

Review-only generation service URL: [enter in App Store Connect]

API format and model: [enter in App Store Connect]

Review-only API key: [enter in App Store Connect]

Optional judge service URL, model, and key: [enter in App Store Connect, or state that judging is not configured]

Test credentials should remain valid through review, have an appropriate spend limit, and be revoked after approval. If the test service requires an allowlist, permit Apple's review traffic or use a service without one.
