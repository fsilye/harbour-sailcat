# 04 — Dynamic Model List from API

**Status:** todo
**Depends on:** nothing
**Touches:** `src/mistralapi.{h,cpp}`, `src/settingsmanager.{h,cpp}`, `qml/pages/SettingsPage.qml`, `qml/components/ModelSelector.qml`

## Goal

Fetch the list of available models from the Mistral API instead of hardcoding three models, with caching and a hardcoded fallback. The hardcoded list is stale (missing `mistral-medium-latest`, `magistral-*` reasoning models, `codestral-*`, etc.).

## API reference

```
GET https://api.mistral.ai/v1/models
Authorization: Bearer <key>
```

Response:

```json
{"object": "list", "data": [
  {"id": "mistral-small-latest", "object": "model", "capabilities": {"completion_chat": true, "vision": false}, ...},
  {"id": "pixtral-12b-latest", "capabilities": {"completion_chat": true, "vision": true}, ...}
]}
```

Filtering rules:
- Keep only models where `capabilities.completion_chat == true`.
- Keep only ids ending in `-latest` (drops dozens of dated aliases like `mistral-small-2409`).
- Sort alphabetically.
- Record `capabilities.vision` per model — feature 09 needs it.

## Implementation

### MistralAPI

```cpp
Q_INVOKABLE void fetchModels(const QString &apiKey);
signals:
void modelsFetched(const QVariantList &models); // list of {"id": QString, "vision": bool}
void modelsFetchFailed();
```

Use a separate `QNetworkReply` (same pattern as `generateTitle`, do not touch `m_currentReply`/`m_isBusy`). Non-streaming GET. Parse, filter, emit. On any error emit `modelsFetchFailed()` and log with `qWarning()`.

### SettingsManager

Cache the fetched list so the UI works offline and on first paint:

- QSettings keys: `models/cachedList` (QStringList of ids), `models/visionList` (QStringList of vision-capable ids), `models/cacheTimestamp` (qint64 epoch seconds).
- `Q_INVOKABLE QStringList availableModels() const` — return cached list if non-empty, else the current hardcoded fallback `{"mistral-small-latest", "mistral-large-latest", "pixtral-12b-latest"}`.
- `Q_INVOKABLE bool isVisionModel(const QString &modelId) const` — from cache, fallback: true only for ids containing `"pixtral"`.
- `Q_INVOKABLE void updateModelCache(const QVariantList &models)` — write cache + timestamp, emit `availableModelsChanged()`.
- New signal `availableModelsChanged()`.

### QML wiring

- In `SettingsPage.qml`: replace both hardcoded `Repeater` model arrays (model ComboBox) with `settingsManager.availableModels()`. Display name = the raw id (drop the hand-written display names; a helper that prettifies `mistral-small-latest` → "Mistral Small" is optional polish). Keep `getModelDescription()` only if trivially adaptable, otherwise delete it.
- In `ModelSelector.qml`: same replacement (read the file first — it currently has its own hardcoded list).
- Trigger a refresh: in `SettingsPage.qml` `Component.onCompleted`, if `settingsManager.hasApiKey` and cache older than 24h (or empty), call `mistralApi.fetchModels(settingsManager.apiKey)`. Handle `onModelsFetched: settingsManager.updateModelCache(models)` in a `Connections` block, then rebuild the ComboBox model.
- `modelsFetchFailed` → silent (cache/fallback already covers the UI); do not surface an error banner for this.

## Acceptance criteria

- [ ] With no network and empty cache, the three fallback models appear (no regression).
- [ ] With a valid key, the ComboBox lists the current `-latest` chat models after opening Settings.
- [ ] Selecting a fetched model persists it and it is used for the next request.
- [ ] Cache survives restart; no refetch within 24h.
- [ ] Docker build passes.
