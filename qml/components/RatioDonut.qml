import QtQuick 2.0
import Sailfish.Silica 1.0

// Animated donut chart: the arc sweeps from 0 to `ratio` when `go` flips to true
Item {
    id: donut

    property real ratio: 0        // 0..1
    property bool go: false
    property string label: ""

    property real animatedRatio: go ? ratio : 0

    width: Theme.itemSizeLarge * 1.5
    height: width

    Behavior on animatedRatio {
        NumberAnimation {
            duration: 1100
            easing.type: Easing.OutCubic
        }
    }

    onAnimatedRatioChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var lineW = Theme.paddingMedium
            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - lineW / 2

            ctx.lineWidth = lineW
            ctx.lineCap = "round"

            // Background ring
            ctx.strokeStyle = Theme.rgba(Theme.secondaryHighlightColor, 0.3)
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()

            // Value arc, starting at 12 o'clock
            if (donut.animatedRatio > 0) {
                ctx.strokeStyle = Theme.highlightColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + donut.animatedRatio * 2 * Math.PI)
                ctx.stroke()
            }
        }
    }

    Column {
        anchors.centerIn: parent

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(donut.animatedRatio * 100) + "%"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: donut.label
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
        }
    }
}
