import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: settingsPage

    allowedOrientations: Orientation.All

    property var availableModelsList: settingsManager.availableModels()

    canAccept: apiKeyField.text.trim().length > 0 || !useCustomKeySwitch.checked

    onAccepted: {
        if (useCustomKeySwitch.checked) {
            settingsManager.apiKey = apiKeyField.text.trim()
            settingsManager.useCustomKey = true
        } else {
            settingsManager.useCustomKey = false
            settingsManager.apiKey = ""
        }

        var selectedModel = modelComboBox.currentItem ?
                            modelComboBox.currentItem.modelValue :
                            "mistral-small-latest"
        settingsManager.modelName = selectedModel

        settingsManager.temperature = customTemperatureSwitch.checked ?
                                      temperatureSlider.value : -1.0
        settingsManager.maxTokens = limitTokensSwitch.checked ?
                                    Math.round(maxTokensSlider.value) : 0

        if (systemPromptComboBox.currentItem) {
            var preset = systemPromptComboBox.currentItem.promptValue
            settingsManager.systemPrompt = preset === "__custom__" ?
                                           customPromptArea.text.trim() : preset
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHeader {
                title: qsTr("Settings & About")
                acceptText: qsTr("Save")
                cancelText: qsTr("Cancel")
            }

            // App Info Section
            Item {
                width: parent.width
                height: Theme.itemSizeLarge

                Icon {
                    anchors.centerIn: parent
                    source: "image://theme/icon-l-message"
                    width: Theme.iconSizeLarge
                    height: Theme.iconSizeLarge
                    color: Theme.highlightColor
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SailCat"
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Version %1").arg(updateChecker.currentVersion)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            // Statistics Section
            SectionHeader {
                text: qsTr("Statistics")
            }

            BackgroundItem {
                width: parent.width

                onClicked: pageStack.push(Qt.resolvedUrl("StatsPage.qml"))

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("View statistics")
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Icon {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    source: "image://theme/icon-m-right"
                }
            }

            // API Configuration Section
            SectionHeader {
                text: qsTr("API Configuration")
            }

            TextSwitch {
                id: useCustomKeySwitch
                text: qsTr("Use my own API key")
                description: qsTr("Enable this option to use your personal Mistral API key")
                checked: settingsManager.useCustomKey
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("To get a free API key, visit console.mistral.ai")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
                visible: useCustomKeySwitch.checked
            }

            TextField {
                id: apiKeyField
                width: parent.width
                label: qsTr("Mistral API Key")
                placeholderText: qsTr("Enter your API key")
                text: settingsManager.apiKey
                visible: useCustomKeySwitch.checked
                enabled: useCustomKeySwitch.checked
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: settingsPage.accept()
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear API key")
                visible: settingsManager.hasApiKey && useCustomKeySwitch.checked
                onClicked: {
                    remorse.execute(qsTr("Clearing API key"), function() {
                        apiKeyField.text = ""
                        settingsManager.clearApiKey()
                    })
                }
            }

            // Language Selection Section
            SectionHeader {
                text: qsTr("Language")
            }

            ComboBox {
                id: languageComboBox
                label: qsTr("Application Language")
                description: qsTr("Select the language for the interface")
                width: parent.width

                menu: ContextMenu {
                    Repeater {
                        model: [
                            { name: "English", value: "en" },
                            { name: "Français", value: "fr" },
                            { name: "Deutsch", value: "de" },
                            { name: "Español", value: "es" },
                            { name: "Suomi", value: "fi" },
                            { name: "Italiano", value: "it" }
                        ]

                        MenuItem {
                            text: modelData.name
                            property string langValue: modelData.value
                        }
                    }
                }

                Component.onCompleted: {
                    var currentLang = settingsManager.language
                    var languages = ["en", "fr", "de", "es", "fi", "it"]
                    var index = languages.indexOf(currentLang)
                    if (index >= 0) {
                        currentIndex = index
                    } else {
                        currentIndex = 0
                    }
                }

                onCurrentItemChanged: {
                    if (currentItem) {
                        settingsManager.language = currentItem.langValue
                    }
                }
            }

            // Model Selection Section
            SectionHeader {
                text: qsTr("Model")
            }

            ComboBox {
                id: modelComboBox
                label: qsTr("Mistral Model")
                description: qsTr("Select the model to use")
                width: parent.width

                menu: ContextMenu {
                    Repeater {
                        model: settingsPage.availableModelsList

                        MenuItem {
                            text: prettyModelName(modelData)
                            property string modelValue: modelData
                        }
                    }
                }

                function selectCurrentModel() {
                    var index = settingsPage.availableModelsList.indexOf(settingsManager.modelName)
                    currentIndex = index >= 0 ? index : 0
                }

                Component.onCompleted: selectCurrentModel()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: modelComboBox.currentItem &&
                      settingsManager.isVisionModel(modelComboBox.currentItem.modelValue)
                      ? qsTr("This model can analyze images") : ""
                visible: text !== ""
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            // Generation Parameters Section
            SectionHeader {
                text: qsTr("Generation")
            }

            TextSwitch {
                id: customTemperatureSwitch
                text: qsTr("Custom temperature")
                description: qsTr("Lower is more focused, higher is more creative")
                checked: settingsManager.temperature >= 0.0
            }

            Slider {
                id: temperatureSlider
                width: parent.width
                visible: customTemperatureSwitch.checked
                minimumValue: 0.0
                maximumValue: 1.5
                stepSize: 0.1
                value: settingsManager.temperature >= 0.0 ? settingsManager.temperature : 0.7
                valueText: value.toFixed(1)
                label: qsTr("Temperature")
            }

            TextSwitch {
                id: limitTokensSwitch
                text: qsTr("Limit response length")
                description: qsTr("Maximum number of tokens per response")
                checked: settingsManager.maxTokens > 0
            }

            Slider {
                id: maxTokensSlider
                width: parent.width
                visible: limitTokensSwitch.checked
                minimumValue: 256
                maximumValue: 8192
                stepSize: 256
                value: settingsManager.maxTokens > 0 ? settingsManager.maxTokens : 1024
                valueText: Math.round(value)
                label: qsTr("Max tokens")
            }

            // System Prompt Section
            SectionHeader {
                text: qsTr("System prompt")
            }

            ComboBox {
                id: systemPromptComboBox
                label: qsTr("Persona")
                description: qsTr("Instruction sent before every conversation")
                width: parent.width

                // Preset prompts are sent to the API: keep them in English, untranslated
                property var presets: [
                    { name: qsTr("None"), value: "" },
                    { name: qsTr("Concise"), value: "Be concise. Answer directly without filler or repetition." },
                    { name: qsTr("Translator"), value: "You are a translator. Translate the user's message to English if it is in another language, otherwise to French. Output only the translation." },
                    { name: qsTr("Code assistant"), value: "You are a programming assistant. Prefer short code examples. Assume the user is an experienced developer." },
                    { name: qsTr("Custom"), value: "__custom__" }
                ]

                menu: ContextMenu {
                    Repeater {
                        model: systemPromptComboBox.presets

                        MenuItem {
                            text: modelData.name
                            property string promptValue: modelData.value
                        }
                    }
                }

                Component.onCompleted: {
                    var current = settingsManager.systemPrompt
                    if (current === "") {
                        currentIndex = 0
                        return
                    }
                    for (var i = 1; i < presets.length - 1; i++) {
                        if (presets[i].value === current) {
                            currentIndex = i
                            return
                        }
                    }
                    currentIndex = presets.length - 1  // Custom
                }
            }

            TextArea {
                id: customPromptArea
                width: parent.width
                visible: systemPromptComboBox.currentItem &&
                         systemPromptComboBox.currentItem.promptValue === "__custom__"
                label: qsTr("Custom system prompt")
                placeholderText: qsTr("Enter a custom system prompt...")

                Component.onCompleted: {
                    var current = settingsManager.systemPrompt
                    if (current === "") return
                    var presets = systemPromptComboBox.presets
                    for (var i = 1; i < presets.length - 1; i++) {
                        if (presets[i].value === current) return
                    }
                    text = current
                }
            }

            // About Section
            SectionHeader {
                text: qsTr("About")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("SailCat is an elegant client for Mistral AI Chat, " +
                      "specifically designed for Sailfish OS.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("• Conversations stored locally\n• No sync with Mistral web\n• Requires personal API key")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Source code on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/harbour-sailcat")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Powered by Mistral AI • MIT License")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Made with <3 for Sailfish OS")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    RemorsePopup {
        id: remorse
    }

    Connections {
        target: mistralApi

        onModelsFetched: {
            settingsManager.updateModelCache(models)
            settingsPage.availableModelsList = settingsManager.availableModels()
            modelComboBox.selectCurrentModel()
        }
    }

    Component.onCompleted: {
        if (settingsManager.hasApiKey && settingsManager.modelCacheStale()) {
            mistralApi.fetchModels(settingsManager.apiKey)
        }
    }

    function prettyModelName(id) {
        var parts = id.replace(/-latest$/, "").split("-")
        for (var i = 0; i < parts.length; i++) {
            parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
        }
        return parts.join(" ")
    }
}
