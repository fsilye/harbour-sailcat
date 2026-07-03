import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import "../components"

Page {
    id: chatPage
    objectName: "chatPage"
    allowedOrientations: Orientation.All

    property bool firstUse: false
    property string streamingContent: ""
    property bool autoScroll: true

    SilicaListView {
        id: messageListView
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: inputArea.top
        }
        clip: true

        model: conversationModel
        spacing: Theme.paddingMedium

        // Stop following the stream when the user scrolls away,
        // resume when they come back to the bottom
        onMovementStarted: chatPage.autoScroll = false
        onMovementEnded: chatPage.autoScroll = messageListView.atYEnd

        header: PageHeader {
            title: "SailCat"
            description: settingsManager.modelName
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Conversation History")
                onClicked: pageStack.push(Qt.resolvedUrl("ConversationHistoryPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings & About")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Change model for next message")
                onClicked: modelSelector.open()
            }
            MenuItem {
                text: qsTr("Export conversation")
                enabled: conversationModel.count > 0
                onClicked: {
                    var path = conversationManager.exportConversation(conversationManager.currentConversationId())
                    if (path !== "") {
                        exportNotification.previewSummary = qsTr("Conversation exported")
                        exportNotification.previewBody = path
                    } else {
                        exportNotification.previewSummary = qsTr("Export failed")
                        exportNotification.previewBody = ""
                    }
                    exportNotification.publish()
                }
            }
            MenuItem {
                text: qsTr("New conversation")
                enabled: conversationModel.count > 0
                onClicked: {
                    conversationManager.createNewConversation()
                    streamingContent = ""
                }
            }
        }

        ViewPlaceholder {
            enabled: conversationModel.count === 0
            text: firstUse ? qsTr("Welcome to SailCat") : qsTr("Start a conversation")
            hintText: firstUse ? qsTr("Configure your Mistral API key to get started") : qsTr("Type a message below")
        }

        delegate: MessageBubble {
            width: messageListView.width
            role: model.role
            content: model.content
            isLast: index === messageListView.count - 1

            onRegenerateRequested: chatPage.regenerateLastResponse()
            onEditRequested: chatPage.editMessage(index, model.content)
        }

        VerticalScrollDecorator {}
    }

    // Footer with input area
    Column {
        id: inputArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        spacing: 0

        // Error banner
        Rectangle {
            width: parent.width
            height: mistralApi.error !== "" ? errorLabel.height + Theme.paddingMedium * 2 : 0
            color: Theme.rgba(Theme.errorColor, 0.2)
            visible: height > 0

            Behavior on height { NumberAnimation { duration: 200 } }

            Label {
                id: errorLabel
                anchors {
                    left: parent.left
                    right: closeErrorButton.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.paddingMedium
                }
                text: mistralApi.error
                color: Theme.errorColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            IconButton {
                id: closeErrorButton
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Theme.paddingMedium
                }
                icon.source: "image://theme/icon-m-clear"
                onClicked: mistralApi.clearError()
            }
        }

        Separator {
            width: parent.width
            color: Theme.highlightColor
            opacity: 0.3
        }

        // Input row
        Item {
            width: parent.width
            height: Math.max(messageInput.height, Theme.itemSizeSmall) + Theme.paddingMedium * 2

            Row {
                anchors {
                    fill: parent
                    margins: Theme.paddingMedium
                }
                spacing: Theme.paddingMedium

                TextArea {
                    id: messageInput
                    width: parent.width - sendButton.width - parent.spacing
                    height: Math.min(implicitHeight, Theme.itemSizeSmall * 2.5)
                    placeholderText: qsTr("Type a message...")
                    labelVisible: false
                    enabled: !mistralApi.isBusy && settingsManager.hasApiKey
                    font.pixelSize: Theme.fontSizeSmall

                    EnterKey.enabled: text.trim().length > 0 && !mistralApi.isBusy
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.onClicked: sendMessage()
                }

                IconButton {
                    id: sendButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: mistralApi.isBusy
                        ? "image://theme/icon-m-pause"
                        : "image://theme/icon-m-message"
                    enabled: (!mistralApi.isBusy && messageInput.text.trim().length > 0 && settingsManager.hasApiKey) || mistralApi.isBusy

                    onClicked: {
                        if (mistralApi.isBusy) {
                            mistralApi.cancelRequest()
                        } else {
                            sendMessage()
                        }
                    }
                }
            }
        }

        // Busy indicator
        Item {
            width: parent.width
            height: mistralApi.isBusy ? Theme.itemSizeExtraSmall : 0
            visible: height > 0

            BusyIndicator {
                anchors.centerIn: parent
                running: mistralApi.isBusy
                size: BusyIndicatorSize.Small
            }
        }
    }

    // Docked panel for conversation history (swipe right)
    DockedPanel {
        id: conversationPanel
        width: parent.width
        height: parent.height
        dock: Dock.Left
        open: false

        SilicaListView {
            anchors.fill: parent

            header: PageHeader {
                title: qsTr("Conversations")
            }

            model: ListModel {
                id: conversationsListModel
            }

            delegate: ListItem {
                id: conversationItem
                contentHeight: Theme.itemSizeMedium

                onClicked: {
                    conversationManager.loadConversation(model.id)
                    conversationPanel.hide()
                    streamingContent = ""
                }

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Delete")
                        onClicked: {
                            conversationItem.remorseAction(qsTr("Deleting"), function() {
                                conversationManager.deleteConversation(model.id)
                                refreshConversationsList()
                            })
                        }
                    }
                }

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: model.title
                        color: conversationItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                    }

                    Row {
                        spacing: Theme.paddingMedium

                        Label {
                            text: Qt.formatDateTime(new Date(model.updatedAt), "dd/MM/yyyy")
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            text: "•"
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            text: qsTr("%n message(s)", "", model.messageCount)
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            ViewPlaceholder {
                enabled: conversationsListModel.count === 0
                text: qsTr("No conversations")
                hintText: qsTr("Start chatting to create conversations")
            }

            VerticalScrollDecorator {}
        }

        IconButton {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
            }
            icon.source: "image://theme/icon-m-add"
            onClicked: {
                conversationManager.createNewConversation()
                conversationPanel.hide()
                streamingContent = ""
            }
        }
    }

    // First launch dialog
    Dialog {
        id: firstLaunchDialog
        allowedOrientations: Orientation.All
        canAccept: true
        onAccepted: settingsManager.setFirstLaunchComplete()

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: column.height

            Column {
                id: column
                width: parent.width
                spacing: Theme.paddingLarge

                DialogHeader {
                    title: qsTr("Welcome to SailCat")
                    acceptText: qsTr("Get Started")
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "image://theme/icon-l-message"
                    width: Theme.iconSizeExtraLarge
                    height: Theme.iconSizeExtraLarge
                    color: Theme.highlightColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SailCat"
                    font.pixelSize: Theme.fontSizeHuge
                    color: Theme.highlightColor
                }

                SectionHeader {
                    text: qsTr("What is Mistral AI?")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Mistral AI is a European AI company providing state-of-the-art language models. SailCat uses their API to bring intelligent conversations to Sailfish OS.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                SectionHeader {
                    text: qsTr("Privacy & Storage")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Your conversations are stored locally on your device\n• No sync with Mistral's web interface\n• You need your own API key to use the app\n• Your data stays on your phone")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                SectionHeader {
                    text: qsTr("Getting Started")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("1. Get a free API key from console.mistral.ai\n2. Configure it in Settings\n3. Start chatting!")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                }
            }
        }
    }

    RemorsePopup {
        id: remorse
    }

    Notification {
        id: exportNotification
        appName: "SailCat"
    }

    // Connections to API
    Connections {
        target: mistralApi

        onStreamingResponse: {
            streamingContent += content
            conversationModel.updateLastAssistantMessage(streamingContent)
            if (chatPage.autoScroll) {
                messageListView.positionViewAtEnd()
            }
        }

        onMessageSent: {
            streamingContent = ""
        }

        onUsageReceived: {
            conversationManager.addTokenUsage(promptTokens, completionTokens)
        }

        onResponseCompleted: {
            streamingContent = ""

            // Drop the empty assistant bubble left behind by an error or cancel
            conversationModel.removeLastMessageIfEmpty()

            if (chatPage.autoScroll) {
                messageListView.positionViewAtEnd()
            }
            conversationManager.saveCurrentConversation()

            // Generate title after first exchange (2 messages: user + assistant)
            if (conversationModel.count === 2) {
                var firstMessage = conversationModel.getFirstUserMessage()
                if (firstMessage) {
                    mistralApi.generateTitle(settingsManager.apiKey, settingsManager.modelName, firstMessage)
                }
            }
        }

        onTitleGenerated: {
            conversationManager.updateCurrentConversationTitle(title)
        }
    }

    Connections {
        target: settingsManager

        onApiKeyChanged: {
            firstUse = !settingsManager.hasApiKey
        }
    }

    Component.onCompleted: {
        firstUse = !settingsManager.hasApiKey
        refreshConversationsList()

        // Show first launch dialog after a short delay to let PageStack settle
        if (settingsManager.isFirstLaunch()) {
            firstLaunchTimer.start()
        }
    }

    Timer {
        id: firstLaunchTimer
        interval: 500
        repeat: false
        onTriggered: firstLaunchDialog.open()
    }

    function sendMessage() {
        var message = messageInput.text.trim()
        if (message.length === 0) return

        if (!settingsManager.hasApiKey) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            return
        }

        messageInput.text = ""
        messageInput.focus = false
        autoScroll = true
        conversationModel.addUserMessage(message)

        var apiKey = settingsManager.apiKey
        var messages = conversationModel.getMessagesForApi()

        if (settingsManager.systemPrompt !== "") {
            messages = [{ "role": "system", "content": settingsManager.systemPrompt }].concat(messages)
        }

        // Use nextMessageModel if set, otherwise use default model
        var actualModel = settingsManager.nextMessageModel !== "" ?
                          settingsManager.nextMessageModel :
                          settingsManager.modelName

        conversationModel.addAssistantMessage("")
        mistralApi.sendMessage(apiKey, actualModel, messages,
                               settingsManager.temperature, settingsManager.maxTokens)

        // Reset next message model after sending
        settingsManager.resetNextMessageModel()

        messageListView.positionViewAtEnd()
    }

    function editMessage(index, content) {
        if (mistralApi.isBusy) return

        conversationModel.truncateFrom(index)
        // Save immediately so a close before resending does not restore the removed tail
        conversationManager.saveCurrentConversation()
        messageInput.text = content
        messageInput.focus = true
    }

    function regenerateLastResponse() {
        if (mistralApi.isBusy) return

        conversationModel.removeLastAssistantMessage()

        var messages = conversationModel.getMessagesForApi()
        if (settingsManager.systemPrompt !== "") {
            messages = [{ "role": "system", "content": settingsManager.systemPrompt }].concat(messages)
        }

        autoScroll = true
        conversationModel.addAssistantMessage("")
        mistralApi.sendMessage(settingsManager.apiKey, settingsManager.modelName, messages,
                               settingsManager.temperature, settingsManager.maxTokens)
    }

    function refreshConversationsList() {
        conversationsListModel.clear()
        var conversations = conversationManager.getConversationsList()
        for (var i = 0; i < conversations.length; i++) {
            conversationsListModel.append(conversations[i])
        }
    }

    ModelSelector {
        id: modelSelector

        onModelSelected: function(selectedModel) {
            settingsManager.nextMessageModel = selectedModel
            remorse.show(qsTr("Model changed to %1 for next message").arg(selectedModel))
        }
    }
}
