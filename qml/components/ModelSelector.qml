import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: modelSelectorDialog
    allowedOrientations: Orientation.All

    property var onModelSelected: function(model) {}

    function prettyModelName(id) {
        var parts = id.replace(/-latest$/, "").split("-")
        for (var i = 0; i < parts.length; i++) {
            parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
        }
        return parts.join(" ")
    }

    Component.onCompleted: {
        var models = settingsManager.availableModels()
        for (var i = 0; i < models.length; i++) {
            modelListModel.append({
                name: prettyModelName(models[i]),
                value: models[i],
                desc: settingsManager.isVisionModel(models[i]) ? qsTr("Vision capable") : ""
            })
        }
    }

    DialogHeader {
        title: qsTr("Select Model")
    }

    SilicaFlickable {
        anchors.fill: parent

        ListModel {
            id: modelListModel
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
