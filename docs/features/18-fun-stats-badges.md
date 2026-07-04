# 18 — Fun Stats, Badges & Cover Mini-Stats

**Status:** done (v2.0.3)
**Depends on:** 17 (stats infrastructure)
**Touches:** `src/conversationmanager.{h,cpp}`, `src/settingsmanager.{h,cpp}`, `qml/pages/StatsPage.qml`, `qml/cover/CoverPage.qml`, translations

## Backend

- `ConversationManager::getFunStats()`: `topWords` (top 5 words in assistant replies, >= 4 letters, FR+EN stopword filter), `longestUserChars`, `avgSendHour` (user messages), `avgGapSecs` (between consecutive user messages, gaps > 30 min ignored as separate sessions), `ghostCount` (conversations with exactly one user message).
- `SettingsManager`: persisted `stats/modelSwitches` counter incremented on every effective `setModelName`, exposed via `modelSwitches()`.

## Badges (StatsPage)

Colored cards in a 2-column grid, tier color green/orange/pink:

| Badge | Tiers |
|---|---|
| Model Hopper | Loyal (<5 switches) / Explorer (5-20) / Chaotic (>20) |
| Longest Message | Concise (<280 chars) / Novelist (280-2000) / TL;DR (>2000) |
| Night Owl | Early Bird (6h-12h) / Normal / Night Owl (0h-6h), from average send hour |
| Speed Typist | Speedy (<10s) / Normal / Snail (>5min), from average gap between messages |
| Conversation Ghost | Finisher (0 abandoned) / Wanderer (1-5) / Ghost (>5) |

## Top words

"Top words in AI replies" section: 5 horizontal bars sized by frequency, animated with the shared `chartProgress`.

## Cover mini-stats

Bottom of the cover, under a thin separator: conversation count and total tokens (fallback: tokens this month). Refreshes with the existing cover refresh hooks.

## Notes

- All 28 new strings translated in the six languages.
- No emoji in the UI (Sailfish font rendering + project convention); tiers use colors instead.

## Acceptance criteria

- [ ] Badges appear with sensible tiers after real usage; no crash with an empty history.
- [ ] Top words exclude stopwords and short words; bars animate on open.
- [ ] Cover shows the two mini-stat lines and updates after a response.
