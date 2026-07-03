# 02 — System Prompt / Personas

**Status:** todo
**Depends on:** nothing
**Touches:** `src/settingsmanager.{h,cpp}`, `qml/pages/ChatPage.qml`, `qml/pages/SettingsPage.qml`

## Goal

Let the user define a system prompt sent as the first message of every request. Ship a few built-in presets ("personas") plus a free-text custom prompt. The system prompt is a global setting, NOT stored inside conversations (so changing it affects the next request of any conversation, and history files keep only user/assistant messages).

## API reference

The system prompt is a regular message prepended to the `messages` array:

```json
{"messages": [
  {"role": "system", "content": "You are a helpful assistant. Answer in French."},
  {"role": "user", "content": "..."}
]}
```

## Implementation

### SettingsManager

Add persisted property (QSettings key `generation/systemPrompt`):

```cpp
Q_PROPERTY(QString systemPrompt READ systemPrompt WRITE setSystemPrompt NOTIFY systemPromptChanged)
```

Default: empty string (= no system message sent).

### ChatPage.qml

In `sendMessage()`, after `var messages = conversationModel.getMessagesForApi()`:

```js
if (settingsManager.systemPrompt !== "") {
    messages.unshift({ "role": "system", "content": settingsManager.systemPrompt })
}
```

`getMessagesForApi()` returns a QVariantList which arrives as a JS array in QML, so `unshift` works. Verify this at runtime; if the returned value is not a mutable JS array, build a new array instead: `messages = [sysMsg].concat(messages)`.

Do the same prepend in the regenerate flow once feature 05 exists.

### SettingsPage.qml

New `SectionHeader { text: qsTr("System prompt") }` with:

1. A `ComboBox` of presets:
   - `qsTr("None")` → `""`
   - `qsTr("Concise")` → `"Be concise. Answer directly without filler or repetition."`
   - `qsTr("Translator")` → `"You are a translator. Translate the user's message to English if it is in another language, otherwise to French. Output only the translation."`
   - `qsTr("Code assistant")` → `"You are a programming assistant. Prefer short code examples. Assume the user is an experienced developer."`
   - `qsTr("Custom")` → enables the TextArea below
2. A `TextArea { placeholderText: qsTr("Enter a custom system prompt...") }`, visible only when Custom is selected, pre-filled with `settingsManager.systemPrompt` when it doesn't match any preset.
3. On `Component.onCompleted`, select the preset matching the stored value, else Custom (or None if empty).
4. Save in the Dialog's `onAccepted`.

Preset strings are sent to the API, not shown in UI — keep them in English and NOT wrapped in `qsTr()`; only the preset display names are translated.

## Acceptance criteria

- [ ] Empty system prompt (default) → request body identical to before.
- [ ] With prompt set, first element of `messages` in the request is the system message; conversation JSON saved on disk contains no system message.
- [ ] Preset selection round-trips after app restart; custom text round-trips too.
- [ ] Title generation (`generateTitle`) is unaffected (it has its own system message).
- [ ] Docker build passes.
