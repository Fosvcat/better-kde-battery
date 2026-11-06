/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// better-kde-battery: a color setting in the settings dialog. An empty value
// means "use the default color", which follows the color scheme.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

RowLayout {
    id: root

    // "" or "#rrggbb"
    property string value: ""
    // Color used while value is empty
    property color defaultColor
    property string dialogTitle

    signal edited(string value)

    spacing: Kirigami.Units.smallSpacing

    KQuickControls.ColorButton {
        color: root.value !== "" ? root.value : root.defaultColor
        dialogTitle: root.dialogTitle
        showAlphaChannel: false
        onAccepted: color => root.edited(color.toString())
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: root.value !== "" ? root.value.toUpperCase()
                                : i18nc("@info The color setting uses its default value", "Default")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        opacity: root.value !== "" ? 1 : 0.7
    }

    QQC2.ToolButton {
        visible: root.value !== ""
        icon.name: "edit-reset"
        display: QQC2.AbstractButton.IconOnly
        text: i18nc("@action:button", "Use Default Color")
        onClicked: root.edited("")

        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }
}
