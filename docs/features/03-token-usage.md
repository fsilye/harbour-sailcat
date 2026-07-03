# 03 — Token Usage Tracking

**Status:** todo
**Depends on:** nothing
**Touches:** `src/mistralapi.{h,cpp}`, `src/conversationmanager.{h,cpp}`, `qml/pages/ChatPage.qml`, `qml/pages/StatsPage.qml`

## Goal

Parse the `usage` object from the streaming response and accumulate token counts, then surface totals in the existing statistics page.

## API reference

The last data chunk before `data: [DONE]` carries usage (and `finish_reason`):

```
data: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":25,"completion_tokens":89,"total_tokens":114}}
```

`usage` may be absent on errors/cancel — treat it as optional.

## Implementation

### MistralAPI

New signal:

```cpp
void usageReceived(int promptTokens, int completionTokens);
```

In `parseStreamLine()`, after parsing `obj`, before/independent of the delta handling:

```cpp
if (obj.contains("usage") && obj["usage"].isObject()) {
    QJsonObject usage = obj["usage"].toObject();
    emit usageReceived(usage["prompt_tokens"].toInt(),
                       usage["completion_tokens"].toInt());
}
```

### ConversationManager

Add two lifetime counters persisted in the same QSettings as conversations (keys `stats/totalPromptTokens`, `stats/totalCompletionTokens`), loaded in the constructor:

```cpp
Q_INVOKABLE void addTokenUsage(int promptTokens, int completionTokens);
```

`addTokenUsage` increments the counters and writes them back immediately (they must survive a crash). Extend `getStatistics()`'s returned QVariantMap with `totalPromptTokens`, `totalCompletionTokens`, `totalTokens`.

Per-conversation token counts are out of scope for this iteration (would require migrating the stored conversation format); lifetime totals only.

### ChatPage.qml

In the `Connections { target: mistralApi }` block:

```js
onUsageReceived: {
    conversationManager.addTokenUsage(promptTokens, completionTokens)
}
```

Signal parameter names must match the C++ signature for QML positional access (Qt 5.6 uses the old-style `onUsageReceived:` handler with implicit parameter names).

### StatsPage.qml

Read the existing structure of the page first, then add a "Tokens" section following its visual conventions, showing: total tokens, prompt tokens, completion tokens (formatted with thousands separators via `Number(n).toLocaleString(Qt.locale(), 'f', 0)`).

## Acceptance criteria

- [ ] After a completed exchange, StatsPage totals increase by the amounts reported in the SSE stream.
- [ ] Cancelled/errored requests do not crash and do not corrupt counters.
- [ ] Counters survive app restart.
- [ ] Docker build passes.
