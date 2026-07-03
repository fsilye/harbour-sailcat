# 01 — Generation Parameters (temperature, max_tokens)

**Status:** todo
**Depends on:** nothing
**Touches:** `src/settingsmanager.{h,cpp}`, `src/mistralapi.{h,cpp}`, `qml/pages/ChatPage.qml`, `qml/pages/SettingsPage.qml`

## Goal

Let the user tune `temperature` and `max_tokens` for chat completions. Defaults must keep current behavior (omit the fields entirely so the API uses its own defaults).

## API reference

Optional fields in the request body of `POST /v1/chat/completions`:

```json
{
  "temperature": 0.7,      // number, 0.0–1.5 (Mistral recommends 0.0–0.7)
  "max_tokens": 1024       // integer > 0; omit for unlimited
}
```

Rule: only include a field in the JSON body when the user has set a non-default value. Never send `temperature: -1` or `max_tokens: 0`.

## Implementation

### SettingsManager

Add two persisted properties (QSettings keys `generation/temperature`, `generation/maxTokens`):

```cpp
Q_PROPERTY(double temperature READ temperature WRITE setTemperature NOTIFY temperatureChanged)
Q_PROPERTY(int maxTokens READ maxTokens WRITE setMaxTokens NOTIFY maxTokensChanged)
```

- `temperature`: default `-1.0` meaning "API default". Valid user range 0.0–1.5.
- `maxTokens`: default `0` meaning "unlimited/API default". Valid user range 1–32000.

Follow the existing pattern in `settingsmanager.cpp` (`loadSettings()` / `saveSettings()`, emit signals only on change).

### MistralAPI

Extend `sendMessage()` with two optional trailing parameters:

```cpp
Q_INVOKABLE void sendMessage(const QString &apiKey,
                             const QString &modelName,
                             const QVariant &messages,
                             double temperature = -1.0,
                             int maxTokens = 0);
```

In the body-building code (after `requestBody["stream"] = true;`):

```cpp
if (temperature >= 0.0)
    requestBody["temperature"] = temperature;
if (maxTokens > 0)
    requestBody["max_tokens"] = maxTokens;
```

Do NOT add these to `generateTitle()` (keep the title request minimal, or set a fixed low `max_tokens` of 30 there — acceptable either way).

### ChatPage.qml

In `sendMessage()`, pass the new arguments:

```js
mistralApi.sendMessage(apiKey, actualModel, messages,
                       settingsManager.temperature, settingsManager.maxTokens)
```

### SettingsPage.qml

Add a new `SectionHeader { text: qsTr("Generation") }` after the Model section, containing:

1. A `Slider` for temperature:
   - `minimumValue: 0.0`, `maximumValue: 1.5`, `stepSize: 0.1`
   - Represent "default" as a `TextSwitch { text: qsTr("Custom temperature") }` above the slider; slider only visible when checked. Switch off → save `-1.0`.
   - `valueText: value.toFixed(1)`, label `qsTr("Temperature")`
   - Description label below: `qsTr("Lower is more focused, higher is more creative")`
2. Same pattern for max tokens: `TextSwitch { text: qsTr("Limit response length") }` + `Slider { minimumValue: 256; maximumValue: 8192; stepSize: 256 }`. Switch off → save `0`.

Persist in the Dialog's `onAccepted`, consistent with how `modelName` is saved.

## Acceptance criteria

- [ ] With both switches off, the JSON request body is byte-identical to before (no new fields).
- [ ] Temperature 0.2 set in settings → request contains `"temperature": 0.2`.
- [ ] Max tokens 1024 → request contains `"max_tokens": 1024` and long answers are truncated by the API.
- [ ] Settings survive app restart.
- [ ] Docker build passes.
