# 12 — Better Markdown Rendering

**Status:** done (v1.9.16)
**Depends on:** 08 (code block regex)
**Touches:** `qml/components/MessageBubble.qml`

## Problems with the previous renderer

1. Bold/italic/link rules ran *inside* code blocks, corrupting code like `**kwargs` or `a * b`.
2. `Text.StyledText` ignores the inline CSS used for code backgrounds, and the hardcoded `rgba(255,255,255,0.1)` assumed a dark ambience anyway (design-polish item 10.1).
3. The italic regex matched lone `*` inside words and URLs.
4. No strikethrough support.

## Approach

- Switch the message Label to `textFormat: Text.RichText` (full Qt rich-text subset: `<pre>`, `<tt>`, `<font>` render correctly).
- Placeholder protection: fenced blocks and inline code are extracted to arrays first (placeholders `\x01N\x01` / `\x02N\x02`), all other rules run on the remaining text, then code is reinserted wrapped in `<pre>`/`<tt>` with `<font color=Theme.highlightColor>` — theme-derived, works on light and dark ambiences.
- Italic regex tightened: `*text*` only matches when not adjacent to word characters or other asterisks, and not across newlines.
- Added `~~text~~` → `<s>`.
- Newline→`<br>` conversion cannot touch code because code is still tokenized at that point; `<pre>` preserves the original newlines natively.

## Acceptance criteria

- [ ] `**kwargs` and `a * b` inside a code block render verbatim.
- [ ] Code visible on light AND dark ambiences (highlight color, no fixed rgba).
- [ ] `*italic*`, `**bold**`, `~~strike~~`, links, headers, bullets still render.
- [ ] URLs containing `*` or `_` are not mangled.
- [ ] Streaming partial messages render without errors (unclosed fence = plain text until closed).
