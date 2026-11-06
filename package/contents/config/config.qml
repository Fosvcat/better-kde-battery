/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nc("@title:group Settings page for the widget's appearance", "Customize")
        icon: "document-edit"
        source: "configCustomize.qml"
    }
}
