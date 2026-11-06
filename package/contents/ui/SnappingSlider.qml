/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// better-kde-battery: a slider that snaps to `step` without tick marks.
// The desktop style draws tick marks for any slider with a stepSize, so the
// slider itself is continuous and the value is rounded here instead.

import QtQuick
import QtQuick.Controls as QQC2

QQC2.Slider {
    id: root

    // The current value, set from outside (e.g. bound to a setting)
    property real snappedValue: 0
    property real step: 1

    // Emitted with the rounded value while dragging
    signal snappedMoved(real value)

    function snap(value: real): real {
        const snapped = from + Math.round((value - from) / step) * step;
        // Avoid floating point noise such as 14.500000001
        return Math.round(Math.max(from, Math.min(to, snapped)) * 1000) / 1000;
    }

    stepSize: 0
    value: snappedValue

    onMoved: {
        const snapped = snap(value);
        if (snapped !== snappedValue) {
            snappedMoved(snapped);
        }
    }

    // Jump the handle to the snapped position when released
    onPressedChanged: {
        if (!pressed) {
            value = Qt.binding(() => root.snappedValue);
        }
    }
}
