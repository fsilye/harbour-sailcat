# Feature Roadmap

Each feature has a detailed spec in `docs/features/`. Implement them one at a time, in order within a phase (later specs sometimes build on earlier ones — dependencies are listed in each spec). Bump a patch version and tag a release after each feature or small batch.

Status legend: `todo` / `in progress` / `done`

## Phase 1 — API quick wins (backend-focused, low risk)

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 01 | Generation parameters (temperature, max_tokens) | [01-generation-parameters.md](features/01-generation-parameters.md) | done (v1.9.7) |
| 02 | System prompt / personas | [02-system-prompt.md](features/02-system-prompt.md) | todo |
| 03 | Token usage tracking | [03-token-usage.md](features/03-token-usage.md) | todo |
| 04 | Dynamic model list from API | [04-dynamic-model-list.md](features/04-dynamic-model-list.md) | todo |

## Phase 2 — Chat UX

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 05 | Regenerate last response | [05-regenerate-response.md](features/05-regenerate-response.md) | todo |
| 06 | Edit user message & resend | [06-edit-message.md](features/06-edit-message.md) | todo |
| 07 | Export conversation | [07-export-conversation.md](features/07-export-conversation.md) | todo |
| 08 | Copy code block | [08-copy-code-block.md](features/08-copy-code-block.md) | todo |

## Phase 3 — Vision

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 09 | Image support for Pixtral | [09-pixtral-vision.md](features/09-pixtral-vision.md) | todo |

## Phase 4 — Design & polish

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 10 | Design fixes (theming, markdown, timestamps, dedup) | [10-design-polish.md](features/10-design-polish.md) | todo |

## Already done (do not re-implement)

- Conversation persistence, history page, search (`ConversationManager::searchConversations` + `SearchField` in ConversationHistoryPage)
- Statistics page with activity charts
- Per-message model override (`nextMessageModel`)
- Auto-generated conversation titles
- Update checker via GitHub Releases
