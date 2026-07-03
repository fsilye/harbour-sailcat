# 16 — Usability: Full Menus Everywhere, Dedicated Model Button

**Status:** done (v1.9.21)
**Depends on:** 11 (PushUpMenu), 13 (pinned page)
**Touches:** `qml/pages/ChatPage.qml`, `qml/pages/ConversationHistoryPage.qml`, `qml/pages/PinnedMessagesPage.qml`

User-requested: the app should be usable without hunting for actions.

## 16.1 Chat: identical top and bottom menus

The PushUpMenu now mirrors every PullDownMenu entry: Conversation History, Pinned messages, Settings & About, Export conversation, New conversation. Export logic factored into `exportCurrentConversation()` to avoid triplication.

## 16.2 History page: useful pulley entries

The history pulley gains Settings & About, Pinned messages (passing the chat page reference found via `pageStack.find` so jump-to-message works) and New conversation (creates and pops back to the chat). Purge stays.

## 16.3 Dedicated model switcher button

An `icon-m-levels` IconButton sits left of the text input and pushes the ModelSelector dialog directly — no menu digging. Semantics changed from the old pulley entry: selection now sets the **default** model (`settingsManager.modelName`, reflected immediately in the page header) instead of a confusing one-shot "next message only" override. Feedback via notification banner.

This also fixes a latent bug: the old entry called `modelSelector.open()`, which does not exist on a Silica Dialog (it must be pushed on the pageStack), so the menu entry was broken at runtime.

## Notes

- The unused RemorsePopup in ChatPage was removed along with the `nextMessageModel` menu entry; the C++ `nextMessageModel` plumbing remains but is no longer set from the UI.
- PinnedMessagesPage now pops directly to the chat page when it has the reference, even when opened from the history page.

## Acceptance criteria

- [ ] Every action available at the top of the chat is available at the bottom.
- [ ] From the history page: settings, pinned messages and new conversation reachable from the pulley.
- [ ] Tapping the levels button next to the input opens the model list; picking one updates the header immediately and persists.
- [ ] Jump-to-pinned works when the pinned page is opened from the history page.
