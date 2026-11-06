/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// better-kde-battery: reads the "Low level" threshold from System Settings >
// Power Management (powerdevilrc [BatteryManagement] BatteryLowLevel,
// default 10%). Call refresh() to read it again.

import QtQuick

import org.kde.plasma.plasma5support as P5Support

QtObject {
    id: root

    property int level: 10

    function refresh() {
        source.connectSource(source.command);
    }

    readonly property P5Support.DataSource source: P5Support.DataSource {
        readonly property string command: "kreadconfig6 --file powerdevilrc --group BatteryManagement --key BatteryLowLevel --default 10"

        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const level = parseInt(data["stdout"]);
            if (level > 0 && level < 100) {
                root.level = level;
            }
            disconnectSource(sourceName);
        }
    }

    Component.onCompleted: refresh()
}
