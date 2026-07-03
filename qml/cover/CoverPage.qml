import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    property string lastMessage: conversationModel.getLastAssistantMessage()

    function refresh() {
        lastMessage = conversationModel.getLastAssistantMessage()
    }

    Connections {
        target: mistralApi
        onResponseCompleted: cover.refresh()
    }

    Connections {
        target: conversationManager
        onCurrentConversationChanged: cover.refresh()
    }

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: Theme.paddingLarge
            leftMargin: Theme.paddingLarge
            rightMargin: Theme.paddingLarge
        }
        spacing: Theme.paddingMedium

        Row {
            spacing: Theme.paddingMedium

            Icon {
                source: "image://theme/icon-m-message"
                color: Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: "SailCat"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Tail of the latest answer, or the message count as fallback
        Label {
            width: parent.width
            text: cover.lastMessage
            visible: cover.lastMessage !== ""
            wrapMode: Text.Wrap
            maximumLineCount: 6
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }

        Label {
            width: parent.width
            text: conversationModel.count > 0
                  ? qsTr("%n message(s)", "", conversationModel.count)
                  : qsTr("No conversation")
            visible: cover.lastMessage === ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }
    }

    CoverActionList {
        id: coverAction

        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                conversationManager.createNewConversation()
            }
        }
    }
}
