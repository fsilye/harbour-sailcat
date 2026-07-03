# 11 — Chat UX Improvements

**Status:** done (v1.9.15)
**Depends on:** 03 (token usage signal), 07 (export action)
**Touches:** `qml/pages/ChatPage.qml`, `qml/pages/ConversationHistoryPage.qml`

User-requested UX fixes for the conversation view.

## 11.1 PushUpMenu (bottom pulley)

In long conversations, reaching the top pulley menu requires scrolling all the way up. Add a `PushUpMenu` to the chat's `SilicaListView` with the two most frequent actions: **New conversation** and **Export conversation** (same handlers as the top menu).

## 11.2 Token usage banner

A thin banner above the input area showing live token usage for the current session:

- `Tokens: <total> total - last: <prompt> in / <completion> out`
- Fed by `usageReceived`; counts accumulate per conversation view (not persisted).
- Reset on `conversationManager.currentConversationChanged` (new/loaded conversation).
- Hidden until the first response completes (`visible: conversationTokens > 0`).

## 11.3 Swipe to conversation list (attached page)

Standard Sailfish pattern (like the Messages app): ConversationHistoryPage is attached to ChatPage via `pageStack.pushAttached()`, so swiping forward from the chat reveals the conversation list. Implementation details:

- Attach in `onStatusChanged` when `status === PageStatus.Active` and `pageStack.nextPage() === null` (re-attaches after Settings pushes replaced the forward stack).
- ConversationHistoryPage refreshes its list on `PageStatus.Activating` since the attached instance stays alive.
- The "Conversation History" pulley item now calls `navigateForward()` instead of pushing a duplicate instance.
- The dead `DockedPanel` conversation list in ChatPage (never opened, duplicate of the history page) was removed (~105 lines), which also covers item 10.4 of the design polish spec.

## Acceptance criteria

- [ ] At the bottom of a long conversation, pulling up reveals New/Export actions.
- [ ] After a response, the banner shows totals; opening another conversation resets it.
- [ ] Swiping forward from the chat opens the history; tapping a conversation swipes back into it, loaded.
- [ ] Page indicator (glow on the right edge) visible on ChatPage.
