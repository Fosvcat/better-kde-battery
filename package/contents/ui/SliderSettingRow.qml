/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// better-kde-battery: a numeric setting in the settings dialog: a slider with
// its current value next to it.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    property real value
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string valueText: Math.round(value * 10) / 10

    signal moved(real value)

    spacing: Kirigami.Units.smallSpacing

    SnappingSlider {
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 6

        from: root.from
        to: root.to
        step: root.stepSize
        snappedValue: root.value

        onSnappedMoved: value => root.moved(value)
    }

    QQC2.Label {
        // Fixed width so the slider does not jump while dragging
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
        horizontalAlignment: Text.AlignRight
        text: root.valueText
        textFormat: Text.PlainText
    }
}
