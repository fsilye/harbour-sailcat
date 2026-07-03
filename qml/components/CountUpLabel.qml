import QtQuick 2.0
import Sailfish.Silica 1.0

// Odometer-style label: counts up from 0 to value when `go` flips to true
Label {
    id: countUp

    property real value: 0
    property bool go: false
    property string prefix: ""
    property string suffix: ""

    property real displayValue: go ? value : 0

    text: prefix + Math.round(displayValue) + suffix

    Behavior on displayValue {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutCubic
        }
    }
}
