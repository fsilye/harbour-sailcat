import QtQuick 2.0
import Sailfish.Silica 1.0

// Three dots bouncing in a staggered wave, chat-style
Row {
    id: typingIndicator

    property bool running: false
    property real dotSize: Theme.paddingMedium

    spacing: dotSize / 2
    height: dotSize * 2.2

    Repeater {
        model: 3

        Item {
            width: typingIndicator.dotSize
            height: typingIndicator.height

            Rectangle {
                id: dot
                width: typingIndicator.dotSize
                height: width
                radius: width / 2
                color: Theme.highlightColor
                y: parent.height - height

                SequentialAnimation {
                    running: typingIndicator.running
                    loops: Animation.Infinite

                    PauseAnimation { duration: index * 140 }
                    NumberAnimation {
                        target: dot
                        property: "y"
                        to: 0
                        duration: 260
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: dot
                        property: "y"
                        to: typingIndicator.height - typingIndicator.dotSize
                        duration: 260
                        easing.type: Easing.InQuad
                    }
                    PauseAnimation { duration: 400 - index * 140 }
                }
            }
        }
    }
}
