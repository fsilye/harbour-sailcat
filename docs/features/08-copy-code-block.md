# 08 — Copy Code Block

**Status:** todo
**Depends on:** nothing
**Touches:** `qml/components/MessageBubble.qml`

## Goal

When an assistant message contains fenced code blocks, offer "Copy code" in the context menu, copying only the code (without the ``` fences or language tag). With multiple blocks, copy them joined by a blank line — per-block selection is out of scope.

## Implementation

All in `MessageBubble.qml`:

```js
function extractCodeBlocks(text) {
    if (!text) return ""
    var blocks = []
    var re = /```[a-zA-Z0-9+#-]*\n?([\s\S]*?)```/g
    var m
    while ((m = re.exec(text)) !== null) {
        var code = m[1]
        // strip single trailing newline
        if (code.charAt(code.length - 1) === '\n') code = code.slice(0, -1)
        if (code.length > 0) blocks.push(code)
    }
    return blocks.join("\n\n")
}
```

Notes:
- Operates on the raw `content` property (pre-HTML-escaping), so no entity decoding needed.
- `[\s\S]*?` (lazy) handles multi-line blocks; the language tag (` ```python `) is consumed by the regex head.
- ES5 only — no arrow functions, no `matchAll`.

Menu item, added after Copy:

```qml
MenuItem {
    text: qsTr("Copy code")
    visible: messageItem.content.indexOf("```") !== -1
    onClicked: Clipboard.text = extractCodeBlocks(messageItem.content)
}
```

## Bonus (same file, optional)

While here, fix the display bug where the language tag leaks into rendered code blocks: in `formatMarkdown()`, change the code-block regex from ``/```([^`]+)```/g`` to ``/```[a-zA-Z0-9+#-]*\n?([\s\S]*?)```/g`` so ` ```python ` headers are stripped from display too. Test with a streaming partial block (odd number of fences) — the lazy regex simply won't match until the closing fence arrives, which is the current behavior anyway.

## Acceptance criteria

- [ ] Message with one ` ```python ... ``` ` block → "Copy code" yields only the code, no fence, no "python".
- [ ] Two blocks → both copied, separated by a blank line.
- [ ] Message without fences → no "Copy code" menu entry.
- [ ] Rendered code blocks no longer show the language tag (if bonus applied).
