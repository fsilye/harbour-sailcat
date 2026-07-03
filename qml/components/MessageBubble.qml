import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: messageItem
    width: parent.width
    contentHeight: Math.max(contentColumn.height + Theme.paddingLarge,
                            busyIndicator.visible ? Theme.itemSizeExtraSmall : 0)

    property string role: "user"
    property string content: ""
    property bool isLast: false
    property bool pinned: false
    property double timestamp: 0

    signal regenerateRequested()
    signal editRequested()
    signal pinToggled()

    menu: ContextMenu {
        MenuItem {
            text: qsTr("Copy")
            onClicked: {
                Clipboard.text = messageItem.content
            }
        }
        MenuItem {
            text: messageItem.pinned ? qsTr("Unpin") : qsTr("Pin")
            onClicked: messageItem.pinToggled()
        }
        MenuItem {
            text: qsTr("Copy code")
            visible: messageItem.content.indexOf("```") !== -1
            onClicked: {
                Clipboard.text = extractCodeBlocks(messageItem.content)
            }
        }
        MenuItem {
            text: qsTr("Edit")
            visible: messageItem.role === "user" && !mistralApi.isBusy
            onClicked: messageItem.editRequested()
        }
        MenuItem {
            text: qsTr("Regenerate")
            visible: messageItem.role === "assistant" && messageItem.isLast && !mistralApi.isBusy
            onClicked: messageItem.regenerateRequested()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: role === "user"
            ? Theme.rgba(Theme.highlightBackgroundColor, 0.15)
            : "transparent"
    }

    // Pinned indicator: thin highlight edge + star in the corner
    Rectangle {
        visible: messageItem.pinned
        width: Theme.paddingSmall / 2
        height: parent.height
        anchors.left: parent.left
        color: Theme.highlightColor
    }

    Icon {
        visible: messageItem.pinned
        source: "image://theme/icon-s-favorite"
        color: Theme.highlightColor
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Theme.paddingSmall
            rightMargin: Theme.paddingSmall
        }
    }

    Column {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: role === "user" ? Theme.horizontalPageMargin * 2 : Theme.horizontalPageMargin
            rightMargin: role === "assistant" ? Theme.horizontalPageMargin * 2 : Theme.horizontalPageMargin
        }
        spacing: Theme.paddingSmall / 2

        Label {
            id: messageLabel
            width: parent.width
            text: formatMarkdown(content)
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primaryColor
            linkColor: Theme.highlightColor
            horizontalAlignment: role === "user" ? Text.AlignRight : Text.AlignLeft
            visible: content !== ""

            onLinkActivated: Qt.openUrlExternally(link)
        }

        Label {
            width: parent.width
            text: messageItem.timestamp > 0
                  ? Qt.formatTime(new Date(messageItem.timestamp), "hh:mm") : ""
            visible: text !== "" && content !== ""
            horizontalAlignment: role === "user" ? Text.AlignRight : Text.AlignLeft
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
        }
    }

    // Streaming placeholder shown inside the pending assistant bubble
    TypingIndicator {
        id: busyIndicator
        visible: role === "assistant" && content === "" && mistralApi.isBusy
        running: visible
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
    }

    function extractCodeBlocks(text) {
        if (!text) return ""

        var blocks = []
        var re = /```[a-zA-Z0-9+#-]*\n?([\s\S]*?)```/g
        var m
        while ((m = re.exec(text)) !== null) {
            var code = m[1]
            if (code.charAt(code.length - 1) === '\n') {
                code = code.slice(0, -1)
            }
            if (code.length > 0) {
                blocks.push(code)
            }
        }
        return blocks.join("\n\n")
    }

    function formatMarkdown(text) {
        if (!text) return ""

        // Escape HTML so raw tags in the response cannot be interpreted
        var formatted = text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')

        // Protect code from the formatting rules below: extract it,
        // substitute placeholders, reinsert at the end
        var codeBlocks = []
        formatted = formatted.replace(/```[a-zA-Z0-9+#-]*\n?([\s\S]*?)```/g, function(match, code) {
            if (code.charAt(code.length - 1) === '\n') {
                code = code.slice(0, -1)
            }
            codeBlocks.push(code)
            return '\x01' + (codeBlocks.length - 1) + '\x01'
        })

        var inlineCodes = []
        formatted = formatted.replace(/`([^`\n]+)`/g, function(match, code) {
            inlineCodes.push(code)
            return '\x02' + (inlineCodes.length - 1) + '\x02'
        })

        // Bold (**text**)
        formatted = formatted.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>')

        // Italic (*text*), not adjacent to word chars or other asterisks
        formatted = formatted.replace(/(^|[\s(])\*([^\*\n]+)\*($|[\s).,;:!?])/gm, '$1<i>$2</i>$3')

        // Strikethrough (~~text~~)
        formatted = formatted.replace(/~~([^~]+)~~/g, '<s>$1</s>')

        // Links [text](url)
        formatted = formatted.replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2">$1</a>')

        // Headers (# text)
        formatted = formatted.replace(/^### (.+)$/gm, '<h3>$1</h3>')
        formatted = formatted.replace(/^## (.+)$/gm, '<h2>$1</h2>')
        formatted = formatted.replace(/^# (.+)$/gm, '<h1>$1</h1>')

        // Bullet points (- item or * item)
        formatted = formatted.replace(/^[\-\*] (.+)$/gm, '• $1')

        // Line breaks (code is still tokenized, so <pre> newlines are preserved)
        formatted = formatted.replace(/\n/g, '<br>')

        // Reinsert code, colored from the theme so it works on any ambience
        var codeColor = "" + Theme.highlightColor
        formatted = formatted.replace(/\x02(\d+)\x02/g, function(match, i) {
            return '<tt><font color="' + codeColor + '">' + inlineCodes[parseInt(i, 10)] + '</font></tt>'
        })
        formatted = formatted.replace(/\x01(\d+)\x01/g, function(match, i) {
            return '<pre><font color="' + codeColor + '">' + codeBlocks[parseInt(i, 10)] + '</font></pre>'
        })

        return formatted
    }
}
