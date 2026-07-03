# 10 — Design & Polish Fixes

**Status:** todo
**Depends on:** nothing (independent items; can be done in any order, each is a standalone commit)

Five small fixes identified by design audit. Each item is one commit.

## 10.1 Theme-aware code styling (`qml/components/MessageBubble.qml`)

`formatMarkdown()` hardcodes `background-color: rgba(255,255,255,0.1)` for `<pre>`/`<code>`. On a light ambience this is invisible/wrong. Qt 5.6 StyledText supports very limited CSS; the reliable approach:

- Replace inline background styling with color only, derived from theme: build the style string in JS using `Theme.highlightColor` (e.g. `'<font color="' + Theme.highlightColor + '">...</font>'` wrapping a `<tt>` monospace tag). StyledText does not honor `background-color` consistently anyway — test on device and prefer `<tt>` + highlight color as the baseline.
- Test with both a dark and a light ambience.

## 10.2 Message timestamps (`qml/components/MessageBubble.qml`, `qml/pages/ChatPage.qml`)

The model already exposes `TimestampRole` (`model.timestamp`, qint64 ms epoch) but it is never displayed.

- Add `property var timestamp` to MessageBubble, bound in the delegate.
- Below the text label, a small label: `Qt.formatTime(new Date(timestamp), "hh:mm")`, `font.pixelSize: Theme.fontSizeTiny`, `color: Theme.secondaryColor`, aligned with the message (right for user, left for assistant). Include it in the contentHeight calculation.
- Show it only when the message is the pressed/expanded one if it feels noisy — first try always-on, decide on device.

## 10.3 Streaming indicator inside the bubble (`qml/pages/ChatPage.qml`, `qml/components/MessageBubble.qml`)

The `BusyIndicator` block under the input area (the `Item` with `height: mistralApi.isBusy ? Theme.itemSizeExtraSmall : 0`) makes the layout jump. Replace it:

- Delete that Item entirely.
- In MessageBubble, when `role === "assistant" && content === "" && mistralApi.isBusy`, show a small inline `BusyIndicator { size: BusyIndicatorSize.ExtraSmall; running: true }` where the text would be. Once the first token arrives, content becomes non-empty and text replaces it automatically.

## 10.4 Remove duplicated conversation panel (`qml/pages/ChatPage.qml`)

ChatPage contains a `DockedPanel` (id `conversationPanel`, ~lines 187–291) listing conversations — a duplicate of `ConversationHistoryPage.qml`, and nothing ever sets `open: true` on it (verify with grep for `conversationPanel` before deleting). Remove:

- The whole `DockedPanel { id: conversationPanel ... }` block.
- The now-unused `conversationsListModel` ListModel and `refreshConversationsList()` function and its call in `Component.onCompleted` (verify no other references first).

The pulley menu entry "Conversation History" already covers the feature.

## 10.5 Cover shows last message (`qml/cover/CoverPage.qml`)

Read the current file first. Replace/augment the message counter with a snippet of the last assistant message:

- Add to ConversationModel: `Q_INVOKABLE QString getLastAssistantMessage() const;` (last message with role assistant, else empty).
- Cover: `Label` with `text` bound to it, `wrapMode: Text.Wrap`, `maximumLineCount: 6`, `truncationMode: TruncationMode.Fade`, `font.pixelSize: Theme.fontSizeExtraSmall`. Fall back to the current counter display when empty.
- Refresh via `Connections { target: mistralApi; onResponseCompleted: ... }` or bind through a NOTIFY-backed property — binding to a `Q_INVOKABLE` is not reactive; simplest correct approach is re-evaluating in a handler: `onResponseCompleted: coverText.text = conversationModel.getLastAssistantMessage()` plus the same in `Component.onCompleted`.
- Keep the existing cover actions.

## Acceptance criteria

- [ ] Code blocks legible on light AND dark ambiences.
- [ ] Timestamps visible, correct local time, layout not broken by long messages.
- [ ] No layout jump when a request starts; spinner appears inside the pending assistant bubble.
- [ ] ChatPage compiles and behaves identically with the DockedPanel removed; app size of ChatPage.qml shrinks by ~100 lines.
- [ ] Cover shows the tail of the latest answer, updates after each response, and app grid shows no regression.
