/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// better-kde-battery: "Customize" settings page. The left half shows a live
// preview of the ring with controls that only affect the preview (they start
// from the system's current state each time the page opens); the right half
// holds the settings and scrolls.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor

KCM.AbstractKCM {
    id: page

    // Settings, read and written by the configuration dialog
    property int cfg_displayMode
    property bool cfg_ringCounterClockwise
    property int cfg_ringScale
    property int cfg_ringThicknessScale
    property string cfg_colorFilled
    property string cfg_colorEmpty
    property int cfg_emptyOpacity
    property string cfg_colorCharging
    property string cfg_colorLow
    property bool cfg_showNumber
    property int cfg_numberSize
    property int cfg_numberWeight
    property bool cfg_numberFollowsRingColor
    property string cfg_colorNumber
    property bool cfg_lowLevelFollowSystem
    property int cfg_lowLevelCustom
    property int cfg_chargingColorWhen
    property int cfg_sleepBlockedSymbol
    property bool cfg_profileIndicator
    property int cfg_profileIndicatorSize
    property int cfg_profileIndicatorPosition
    property string cfg_colorProfilePerformance
    property string cfg_colorProfilePowerSaver

    // Same as the defaults in config/main.xml
    readonly property var defaults: ({
        displayMode: 0,
        ringCounterClockwise: false,
        ringScale: 100,
        ringThicknessScale: 100,
        colorFilled: "",
        colorEmpty: "",
        emptyOpacity: 35,
        colorCharging: "",
        colorLow: "",
        showNumber: true,
        numberSize: 100,
        numberWeight: 1,
        numberFollowsRingColor: true,
        colorNumber: "",
        lowLevelFollowSystem: true,
        lowLevelCustom: 10,
        chargingColorWhen: 0,
        sleepBlockedSymbol: 1,
        profileIndicator: true,
        profileIndicatorSize: 100,
        profileIndicatorPosition: 0,
        colorProfilePerformance: "",
        colorProfilePowerSaver: "",
    })

    readonly property bool isDefault: Object.keys(defaults).every(key => page["cfg_" + key] === defaults[key])

    function restoreDefaults() {
        for (const key of Object.keys(defaults)) {
            page["cfg_" + key] = defaults[key];
        }
    }

    // --- System state, only used as the preview's starting point ---

    BatteryControlModel {
        id: systemBattery
    }

    PowerProfilesControl {
        id: systemProfiles
    }

    InhibitionControl {
        id: systemInhibition
    }

    LowBatteryLevelReader {
        id: systemLowLevel
    }

    // The preview starts from the system's state and follows it (the values
    // arrive asynchronously over D-Bus) until the user changes it: assigning
    // a value from a control replaces the binding. Without power-profiles-
    // daemon the profile simply starts at "balanced".
    QtObject {
        id: preview

        readonly property var profiles: ["power-saver", "balanced", "performance"]

        property int percent: systemBattery.hasCumulative ? systemBattery.percent : 50
        property bool pluggedIn: systemBattery.pluggedIn
        property int profileIndex: {
            const index = profiles.indexOf(systemProfiles.activeProfile);
            return index >= 0 ? index : 1;
        }
        property bool sleepBlocked: systemInhibition.isManuallyInhibited

        readonly property int lowLevel: page.cfg_lowLevelFollowSystem ? systemLowLevel.level : page.cfg_lowLevelCustom
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- Left: preview ---

        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            Layout.maximumWidth: Kirigami.Units.gridUnit * 14
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 4
                text: i18nc("@title:group", "Preview")
                textFormat: Text.PlainText
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 10

                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.cornerRadius
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.gridUnit

                    RingBatteryIcon {
                        id: previewIcon

                        Layout.preferredWidth: Kirigami.Units.iconSizes.enormous
                        Layout.preferredHeight: Kirigami.Units.iconSizes.enormous

                        config: page
                        configPrefix: "cfg_"
                        percent: preview.percent
                        charging: preview.pluggedIn
                        lowLevel: preview.lowLevel
                        powerProfile: preview.profiles[preview.profileIndex]
                        sleepBlocked: preview.sleepBlocked
                    }

                    // Real panel sizes
                    ColumnLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Repeater {
                            model: [Kirigami.Units.iconSizes.smallMedium, Kirigami.Units.iconSizes.medium]

                            RingBatteryIcon {
                                required property int modelData

                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: modelData
                                Layout.preferredHeight: modelData

                                config: page
                                configPrefix: "cfg_"
                                percent: previewIcon.percent
                                charging: previewIcon.charging
                                lowLevel: previewIcon.lowLevel
                                powerProfile: previewIcon.powerProfile
                                sleepBlocked: previewIcon.sleepBlocked
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                text: i18nc("@label:slider Battery level of the preview", "Charge: %1%", preview.percent)
                textFormat: Text.PlainText
            }

            SnappingSlider {
                Layout.fillWidth: true
                from: 0
                to: 100
                step: 1
                snappedValue: preview.percent
                onSnappedMoved: value => preview.percent = value
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18nc("@label:slider Power profile of the preview", "Power profile:")
                textFormat: Text.PlainText
            }

            SnappingSlider {
                Layout.fillWidth: true
                from: 0
                to: 2
                step: 1
                snappedValue: preview.profileIndex
                onSnappedMoved: value => preview.profileIndex = value
            }

            RowLayout {
                Layout.fillWidth: true

                Repeater {
                    model: [
                        i18nc("@label Power profile", "Power Save"),
                        i18nc("@label Power profile", "Balanced"),
                        i18nc("@label Power profile", "Performance"),
                    ]

                    QQC2.Label {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1 // equal thirds
                        horizontalAlignment: index === 0 ? Text.AlignLeft : index === 1 ? Text.AlignHCenter : Text.AlignRight
                        text: modelData
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: preview.profileIndex === index ? 1 : 0.6
                    }
                }
            }

            QQC2.Switch {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                text: i18nc("@option:check Preview state", "Plugged in")
                checked: preview.pluggedIn
                onToggled: preview.pluggedIn = checked
            }

            QQC2.Switch {
                Layout.fillWidth: true
                text: i18nc("@option:check Preview state", "Sleep blocked")
                checked: preview.sleepBlocked
                onToggled: preview.sleepBlocked = checked
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18nc("@info", "These controls only change the preview, not the system.")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            Item {
                Layout.fillHeight: true
            }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        // --- Right: settings ---

        QQC2.ScrollView {
            id: settingsScrollView

            Layout.fillWidth: true
            Layout.fillHeight: true

            contentWidth: availableWidth
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

            GridLayout {
                id: settings

                width: settingsScrollView.availableWidth - Kirigami.Units.largeSpacing * 2
                x: Kirigami.Units.largeSpacing

                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                // Spacer row so the first heading is not glued to the top
                Item {
                    Layout.columnSpan: 2
                    Layout.preferredHeight: Kirigami.Units.smallSpacing
                }

                // --- Ring ---

                SectionHeading {
                    text: i18nc("@title:group", "Ring")
                }

                FormLabel {
                    text: i18nc("@label:listbox", "Display mode:")
                }
                QQC2.ComboBox {
                    Layout.fillWidth: true
                    model: [
                        i18nc("@item:inlistbox Display mode", "Ring starting at 0°"),
                        i18nc("@item:inlistbox Display mode", "Ring starting at 180°"),
                        i18nc("@item:inlistbox Display mode: the ring fills like a container of liquid", "Liquid container"),
                    ]
                    currentIndex: page.cfg_displayMode
                    onActivated: index => page.cfg_displayMode = index
                }

                FormLabel {
                    visible: reverseDirectionCheckBox.visible
                    text: ""
                }
                QQC2.CheckBox {
                    id: reverseDirectionCheckBox

                    Layout.fillWidth: true
                    visible: page.cfg_displayMode !== 2
                    text: i18nc("@option:check Fill the ring counterclockwise", "Reverse direction")
                    checked: page.cfg_ringCounterClockwise
                    onToggled: page.cfg_ringCounterClockwise = checked
                }

                FormLabel {
                    text: i18nc("@label:slider", "Size:")
                }
                SliderSettingRow {
                    Layout.fillWidth: true
                    from: 70
                    to: 130
                    value: page.cfg_ringScale
                    valueText: i18nc("@label Percentage", "%1%", value)
                    onMoved: value => page.cfg_ringScale = value
                }

                FormLabel {
                    text: i18nc("@label:slider", "Thickness:")
                }
                SliderSettingRow {
                    Layout.fillWidth: true
                    from: 70
                    to: 130
                    value: page.cfg_ringThicknessScale
                    valueText: i18nc("@label Percentage", "%1%", value)
                    onMoved: value => page.cfg_ringThicknessScale = value
                }

                // --- Ring colors ---

                SectionHeading {
                    text: i18nc("@title:group", "Ring Colors")
                }

                FormLabel {
                    text: i18nc("@label:chooser", "Remaining charge:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    value: page.cfg_colorFilled
                    defaultColor: Kirigami.Theme.textColor
                    onEdited: value => page.cfg_colorFilled = value
                }

                FormLabel {
                    text: i18nc("@label:chooser", "Used up:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    value: page.cfg_colorEmpty
                    defaultColor: Kirigami.Theme.textColor
                    onEdited: value => page.cfg_colorEmpty = value
                }

                FormLabel {
                    text: i18nc("@label:slider Opacity of the used-up part of the ring", "Used up opacity:")
                }
                SliderSettingRow {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: page.cfg_emptyOpacity
                    valueText: i18nc("@label Percentage", "%1%", value)
                    onMoved: value => page.cfg_emptyOpacity = value
                }

                FormLabel {
                    text: i18nc("@label:chooser", "Charging:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    value: page.cfg_colorCharging
                    defaultColor: Kirigami.Theme.positiveTextColor
                    onEdited: value => page.cfg_colorCharging = value
                }

                FormLabel {
                    text: i18nc("@label:chooser", "Low battery:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    value: page.cfg_colorLow
                    defaultColor: Kirigami.Theme.negativeTextColor
                    onEdited: value => page.cfg_colorLow = value
                }

                // --- Number ---

                SectionHeading {
                    text: i18nc("@title:group", "Number")
                }

                FormLabel {
                    text: ""
                }
                QQC2.CheckBox {
                    Layout.fillWidth: true
                    text: i18nc("@option:check", "Show the battery level in the ring")
                    checked: page.cfg_showNumber
                    onToggled: page.cfg_showNumber = checked
                }

                FormLabel {
                    text: i18nc("@label:slider", "Size:")
                }
                SliderSettingRow {
                    Layout.fillWidth: true
                    enabled: page.cfg_showNumber
                    from: 70
                    to: 130
                    value: page.cfg_numberSize
                    valueText: i18nc("@label Percentage", "%1%", value)
                    onMoved: value => page.cfg_numberSize = value
                }

                FormLabel {
                    text: i18nc("@label:listbox Font weight", "Weight:")
                }
                QQC2.ComboBox {
                    Layout.fillWidth: true
                    enabled: page.cfg_showNumber
                    model: [
                        i18nc("@item:inlistbox Font weight", "Regular"),
                        i18nc("@item:inlistbox Font weight", "Semibold"),
                        i18nc("@item:inlistbox Font weight", "Bold"),
                    ]
                    currentIndex: page.cfg_numberWeight
                    onActivated: index => page.cfg_numberWeight = index
                }

                FormLabel {
                    text: ""
                }
                QQC2.CheckBox {
                    Layout.fillWidth: true
                    text: i18nc("@option:check", "Same color as the ring")
                    checked: page.cfg_numberFollowsRingColor
                    onToggled: page.cfg_numberFollowsRingColor = checked
                }

                FormLabel {
                    text: i18nc("@label:chooser", "Number color:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    enabled: !page.cfg_numberFollowsRingColor
                    value: page.cfg_colorNumber
                    defaultColor: Kirigami.Theme.textColor
                    onEdited: value => page.cfg_colorNumber = value
                }

                // --- Behavior ---

                SectionHeading {
                    text: i18nc("@title:group", "Behavior")
                }

                FormLabel {
                    text: i18nc("@label:listbox", "Low battery at:")
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.ComboBox {
                        Layout.fillWidth: true
                        model: [
                            i18nc("@item:inlistbox %1 is a percentage", "Power Management setting (%1%)", systemLowLevel.level),
                            i18nc("@item:inlistbox", "Custom"),
                        ]
                        currentIndex: page.cfg_lowLevelFollowSystem ? 0 : 1
                        onActivated: index => page.cfg_lowLevelFollowSystem = index === 0
                    }

                    QQC2.SpinBox {
                        visible: !page.cfg_lowLevelFollowSystem
                        from: 1
                        to: 99
                        value: page.cfg_lowLevelCustom
                        textFromValue: (value, locale) => i18nc("@label Percentage", "%1%", value)
                        valueFromText: (text, locale) => parseInt(text)
                        onValueModified: page.cfg_lowLevelCustom = value
                    }
                }

                FormLabel {
                    text: i18nc("@label:listbox", "Charging color:")
                }
                QQC2.ComboBox {
                    Layout.fillWidth: true
                    model: [
                        i18nc("@item:inlistbox Use the charging color…", "As soon as AC is plugged in"),
                        i18nc("@item:inlistbox Use the charging color…", "Only while actually charging"),
                    ]
                    currentIndex: page.cfg_chargingColorWhen
                    onActivated: index => page.cfg_chargingColorWhen = index
                }

                FormLabel {
                    text: i18nc("@label:listbox", "Sleep blocked:")
                }
                QQC2.ComboBox {
                    Layout.fillWidth: true
                    model: [
                        i18nc("@item:inlistbox What the icon shows while sleep is blocked", "No change"),
                        i18nc("@item:inlistbox What the icon shows while sleep is blocked", "Show “-”"),
                        i18nc("@item:inlistbox What the icon shows while sleep is blocked", "Show “*”"),
                        i18nc("@item:inlistbox What the icon shows while sleep is blocked", "Show “!”"),
                    ]
                    currentIndex: page.cfg_sleepBlockedSymbol
                    onActivated: index => page.cfg_sleepBlockedSymbol = index
                }

                // --- Power profile indicator ---

                SectionHeading {
                    text: i18nc("@title:group", "Power Profile Indicator")
                }

                FormLabel {
                    text: ""
                }
                QQC2.CheckBox {
                    Layout.fillWidth: true
                    text: i18nc("@option:check", "Show a dot in power save and performance mode")
                    checked: page.cfg_profileIndicator
                    onToggled: page.cfg_profileIndicator = checked
                }

                FormLabel {
                    text: i18nc("@label:slider", "Size:")
                }
                SliderSettingRow {
                    Layout.fillWidth: true
                    enabled: page.cfg_profileIndicator
                    from: 70
                    to: 130
                    value: page.cfg_profileIndicatorSize
                    valueText: i18nc("@label Percentage", "%1%", value)
                    onMoved: value => page.cfg_profileIndicatorSize = value
                }

                FormLabel {
                    text: i18nc("@label:listbox", "Position:")
                }
                QQC2.ComboBox {
                    Layout.fillWidth: true
                    enabled: page.cfg_profileIndicator
                    model: [
                        i18nc("@item:inlistbox Corner", "Bottom right"),
                        i18nc("@item:inlistbox Corner", "Top right"),
                        i18nc("@item:inlistbox Corner", "Bottom left"),
                        i18nc("@item:inlistbox Corner", "Top left"),
                    ]
                    currentIndex: page.cfg_profileIndicatorPosition
                    onActivated: index => page.cfg_profileIndicatorPosition = index
                }

                FormLabel {
                    text: i18nc("@label:chooser Power profile indicator color", "Performance:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    enabled: page.cfg_profileIndicator
                    value: page.cfg_colorProfilePerformance
                    defaultColor: previewIcon.defaultPerformanceColor
                    onEdited: value => page.cfg_colorProfilePerformance = value
                }

                FormLabel {
                    text: i18nc("@label:chooser Power profile indicator color", "Power save:")
                }
                ColorSettingRow {
                    Layout.fillWidth: true
                    enabled: page.cfg_profileIndicator
                    value: page.cfg_colorProfilePowerSaver
                    defaultColor: previewIcon.defaultPowerSaverColor
                    onEdited: value => page.cfg_colorProfilePowerSaver = value
                }

                // --- Defaults ---

                Item {
                    Layout.columnSpan: 2
                    Layout.preferredHeight: Kirigami.Units.largeSpacing
                }

                Item {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    implicitHeight: defaultsButton.implicitHeight

                    QQC2.Button {
                        id: defaultsButton

                        anchors.right: parent.right
                        enabled: !page.isDefault
                        icon.name: "edit-reset"
                        text: i18nc("@action:button", "Restore Defaults")
                        onClicked: page.restoreDefaults()
                    }
                }
            }
        }
    }

    component SectionHeading: Kirigami.Heading {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        level: 4
        textFormat: Text.PlainText
    }

    // Right-aligned label column, like Kirigami.FormLayout
    component FormLabel: QQC2.Label {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        textFormat: Text.PlainText
    }
}
