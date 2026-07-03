import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: pinnedPage
    allowedOrientations: Orientation.All

    property var chatPage: null

    SilicaListView {
        anchors.fill: parent

        header: PageHeader {
            title: qsTr("Pinned messages")
        }

        model: ListModel {
            id: pinnedModel
        }

        delegate: ListItem {
            id: pinnedItem
            contentHeight: itemColumn.height + Theme.paddingMedium * 2

            onClicked: {
                conversationManager.loadConversation(model.conversationId)
                if (pinnedPage.chatPage) {
                    pinnedPage.chatPage.pendingScrollIndex = model.messageIndex
                }
                pageStack.pop()
            }

            Column {
                id: itemColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall

                Row {
                    spacing: Theme.paddingSmall

                    Icon {
                        source: "image://theme/icon-s-favorite"
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: model.conversationTitle
                        color: pinnedItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                    }
                }

                Label {
                    width: parent.width
                    text: model.content
                    color: pinnedItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Label {
                    text: Qt.formatDateTime(new Date(model.timestamp), "dd/MM/yyyy hh:mm")
                    color: pinnedItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeTiny
                }
            }
        }

        ViewPlaceholder {
            enabled: pinnedModel.count === 0
            text: qsTr("No pinned messages")
            hintText: qsTr("Long-press a message and select Pin")
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: refresh()

    function refresh() {
        pinnedModel.clear()
        var pins = conversationManager.getPinnedMessages()
        for (var i = 0; i < pins.length; i++) {
            pinnedModel.append(pins[i])
        }
    }
}
