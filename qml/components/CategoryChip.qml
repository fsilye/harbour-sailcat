import QtQuick 2.0
import Sailfish.Silica 1.0

// Small colored pill showing a conversation category
Rectangle {
    id: chip

    property string category: ""

    visible: category !== ""
    width: chipLabel.width + Theme.paddingMedium
    height: chipLabel.height + Theme.paddingSmall / 2
    radius: height / 2
    color: Theme.rgba(categoryColor(category), 0.2)
    border.color: Theme.rgba(categoryColor(category), 0.6)
    border.width: 1

    function categoryColor(cat) {
        switch (cat) {
        case "code": return "#4fc3f7"
        case "writing": return "#ba68c8"
        case "translation": return "#4db6ac"
        case "learning": return "#ffb74d"
        case "ideas": return "#f06292"
        case "practical": return "#aed581"
        default: return "#90a4ae"
        }
    }

    function categoryLabel(cat) {
        switch (cat) {
        case "code": return qsTr("Code")
        case "writing": return qsTr("Writing")
        case "translation": return qsTr("Translation")
        case "learning": return qsTr("Learning")
        case "ideas": return qsTr("Ideas")
        case "practical": return qsTr("Practical")
        default: return qsTr("Other")
        }
    }

    Label {
        id: chipLabel
        anchors.centerIn: parent
        text: chip.categoryLabel(chip.category)
        font.pixelSize: Theme.fontSizeTiny
        color: chip.categoryColor(chip.category)
    }
}
