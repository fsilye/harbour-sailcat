import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: modelSelectorDialog
    allowedOrientations: Orientation.All

    property var onModelSelected: function(model) {}

    DialogHeader {
        title: qsTr("Select Model")
    }

    SilicaFlickable {
        anchors.fill: parent

        ListModel {
            id: modelListModel
            ListElement { name: qsTr("Mistral Small (Recommended)"); value: "mistral-small-latest"; desc: qsTr("Balanced model between performance and speed") }
            ListElement { name: qsTr("Mistral Large"); value: "mistral-large-latest"; desc: qsTr("Most powerful for complex tasks") }
            ListElement { name: qsTr("Pixtral 12B (Vision)"); value: "pixtral-12b-latest"; desc: qsTr("Model with image support") }
        }

        ListView {
            anchors.fill: parent
            model: modelListModel
            delegate: ListItem {
                width: parent.width
                contentHeight: Theme.itemSizeMedium

                onClicked: {
                    modelSelectorDialog.accept()
                    onModelSelected(value)
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
                        text: name
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Label {
                        text: desc
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
