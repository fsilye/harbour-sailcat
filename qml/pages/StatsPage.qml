import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: statsPage
    allowedOrientations: Orientation.All

    property var stats: conversationManager.getStatistics()
    property var messagesPerDay: stats.messagesPerDay || []
    property var messagesPerHour: stats.messagesPerHour || []
    property int maxPerDay: maxOf(messagesPerDay)
    property int maxPerHour: maxOf(messagesPerHour)
    property real userRatio: (stats.totalMessages || 0) > 0
                             ? stats.totalUserMessages / stats.totalMessages : 0
    property real chartProgress: 0

    NumberAnimation on chartProgress {
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.OutCubic
    }

    function maxOf(list) {
        var m = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] > m) m = list[i]
        }
        return m
    }

    function formatTokens(n) {
        if (n >= 1000000) return "~" + (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return "~" + (n / 1000).toFixed(1) + "K"
        return "~" + n
    }

    function formatExactTokens(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "K"
        return "" + n
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Statistics")
            }

            // Summary cards
            Grid {
                id: cardsGrid
                columns: 2
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                columnSpacing: Theme.paddingMedium
                rowSpacing: Theme.paddingMedium

                Repeater {
                    model: [
                        { value: "" + (stats.totalConversations || 0), label: qsTr("Conversations") },
                        { value: "" + (stats.totalMessages || 0), label: qsTr("Messages") },
                        { value: (stats.totalTokens || 0) > 0
                                 ? formatExactTokens(stats.totalTokens)
                                 : formatTokens(stats.estimatedTokens || 0),
                          label: qsTr("Tokens used") },
                        { value: conversationManager.getStorageSizeFormatted(), label: qsTr("Storage") }
                    ]

                    Rectangle {
                        width: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                        height: Theme.itemSizeLarge
                        radius: Theme.paddingSmall
                        color: Theme.rgba(Theme.highlightColor, 0.1)

                        Column {
                            anchors.centerIn: parent

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeLarge
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }
                        }
                    }
                }
            }

            // Sent vs received ratio
            SectionHeader {
                text: qsTr("Sent vs received")
                visible: (stats.totalMessages || 0) > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: (stats.totalMessages || 0) > 0

                Rectangle {
                    width: parent.width
                    height: Theme.paddingMedium
                    radius: height / 2
                    color: Theme.rgba(Theme.secondaryHighlightColor, 0.4)

                    Rectangle {
                        width: Math.max(parent.height, parent.width * statsPage.userRatio * statsPage.chartProgress)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.highlightColor
                    }
                }

                Item {
                    width: parent.width
                    height: sentLabel.height

                    Label {
                        id: sentLabel
                        anchors.left: parent.left
                        text: qsTr("Sent: %1").arg(stats.totalUserMessages || 0)
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: qsTr("Received: %1").arg(stats.totalAssistantMessages || 0)
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Daily activity chart
            SectionHeader {
                text: qsTr("Last 14 days")
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Row {
                    id: dayBarsRow
                    width: parent.width
                    height: Theme.itemSizeLarge
                    spacing: Theme.paddingSmall / 2

                    Repeater {
                        model: statsPage.messagesPerDay

                        Item {
                            width: (dayBarsRow.width - dayBarsRow.spacing * 13) / 14
                            height: dayBarsRow.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 2
                                height: statsPage.maxPerDay > 0 && modelData > 0
                                        ? Math.max(6, parent.height * statsPage.chartProgress * modelData / statsPage.maxPerDay)
                                        : 6
                                color: modelData > 0
                                       ? Theme.rgba(Theme.highlightColor,
                                                    0.4 + 0.6 * modelData / statsPage.maxPerDay)
                                       : Theme.rgba(Theme.secondaryColor, 0.2)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: dayStartLabel.height

                    Label {
                        id: dayStartLabel
                        anchors.left: parent.left
                        text: Qt.formatDate(new Date(Date.now() - 13 * 86400000), "dd/MM")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: statsPage.maxPerDay > 0
                              ? qsTr("Peak: %1 messages/day").arg(statsPage.maxPerDay)
                              : qsTr("No recent activity")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: qsTr("Today")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Hourly activity chart
            SectionHeader {
                text: qsTr("Activity by hour")
                visible: statsPage.maxPerHour > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.maxPerHour > 0

                Row {
                    id: hourBarsRow
                    width: parent.width
                    height: Theme.itemSizeMedium
                    spacing: 2

                    Repeater {
                        model: statsPage.messagesPerHour

                        Item {
                            width: (hourBarsRow.width - hourBarsRow.spacing * 23) / 24
                            height: hourBarsRow.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 1
                                height: statsPage.maxPerHour > 0 && modelData > 0
                                        ? Math.max(4, parent.height * statsPage.chartProgress * modelData / statsPage.maxPerHour)
                                        : 4
                                color: modelData > 0
                                       ? Theme.rgba(Theme.highlightColor,
                                                    0.4 + 0.6 * modelData / statsPage.maxPerHour)
                                       : Theme.rgba(Theme.secondaryColor, 0.2)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: hourStartLabel.height

                    Label {
                        id: hourStartLabel
                        anchors.left: parent.left
                        text: "0h"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "12h"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: "23h"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Records
            SectionHeader {
                text: qsTr("Records")
            }

            Column {
                width: parent.width

                DetailItem {
                    label: qsTr("Longest conversation")
                    value: stats.longestConvTitle
                           ? stats.longestConvTitle + " (" + stats.longestConvMessages + ")"
                           : qsTr("None")
                }

                DetailItem {
                    label: qsTr("Longest message")
                    value: qsTr("%n character(s)", "", stats.longestMessageLength || 0)
                }

                DetailItem {
                    label: qsTr("First message")
                    value: stats.firstMessageDate > 0
                           ? Qt.formatDateTime(new Date(stats.firstMessageDate), "dd/MM/yyyy")
                           : qsTr("Never")
                }

                DetailItem {
                    label: qsTr("Prompt tokens")
                    value: "" + (stats.totalPromptTokens || 0)
                    visible: (stats.totalTokens || 0) > 0
                }

                DetailItem {
                    label: qsTr("Completion tokens")
                    value: "" + (stats.totalCompletionTokens || 0)
                    visible: (stats.totalTokens || 0) > 0
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }
}
