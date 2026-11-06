/*
    SPDX-FileCopyrightText: 2011 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2011 Viranch Mehta <viranch.mehta@gmail.com>
    SPDX-FileCopyrightText: 2013-2015 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2021-2022 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2023 Natalie Clarius <natalie.clarius@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCMUtils
import org.kde.config as KConfig
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.battery

PlasmoidItem {
    id: batterymonitor

    PowerProfilesControl {
        id: powerProfilesControl

        readonly property bool isInBalancedProfile: activeProfile === "balanced"
        readonly property bool isInPerformanceProfile: activeProfile === "performance"
        readonly property bool isInPowersaveProfile: activeProfile === "power-saver"
        readonly property bool isHeldOnPowerProfile: profileHolds.length > 0
        readonly property string defaultPowerProfile: configuredProfile ? configuredProfile : "balanced"
        readonly property bool isInDefaultPowerProfile: !activeProfile || activeProfile === defaultPowerProfile
    }

    BatteryControlModel {
        id: batteryControl

        readonly property int remainingTime: smoothedRemainingMsec
        readonly property bool isSomehowFullyCharged: pluggedIn && state === BatteryControlModel.FullyCharged
    }

    InhibitionControl {
        id: inhibitionControl
    }

    // better-kde-battery: the "Low level" threshold from System Settings >
    // Power Management, used to show the ring in red. Re-read whenever the
    // charge changes or the popup is opened, so a changed setting is picked
    // up without restarting Plasma.
    LowBatteryLevelReader {
        id: lowBatteryLevelReader
    }

    readonly property int lowBatteryLevel: Plasmoid.configuration.lowLevelFollowSystem ? lowBatteryLevelReader.level : Plasmoid.configuration.lowLevelCustom

    Connections {
        target: batteryControl
        function onPercentChanged() {
            lowBatteryLevelReader.refresh();
        }
    }

    onExpandedChanged: lowBatteryLevelReader.refresh()

    readonly property bool kcmAuthorized: KConfig.KAuthorized.authorizeControlModule("kcm_powerdevilprofilesconfig")
    readonly property bool kcmEnergyInformationAuthorized: KConfig.KAuthorized.authorizeControlModule("kcm_energyinfo")

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)
    readonly property bool compactInPanel: inPanel && !!compactRepresentationItem?.visible

    function symbolicizeIconName(iconName: string): string {
        const symbolicSuffix = "-symbolic";
        if (iconName.endsWith(symbolicSuffix)) {
            return iconName;
        }

        return iconName + symbolicSuffix;
    }

    signal inhibitionChangeRequested(bool inhibit)

    onInhibitionChangeRequested: inhibit => {
        inhibitionControl.isSilent = expanded; // show OSD only when the plasmoid isn't expanded since the changing switch is feedback enough

        if (inhibit) {
            const reason = i18nd("plasma_applet_org.kde.plasma.battery", "The battery applet has enabled suppressing sleep and screen locking");
            inhibitionControl.inhibit(reason)
        } else {
            inhibitionControl.uninhibit()
        }
    }

    signal activateProfileRequested(string profile)

    onActivateProfileRequested: profile => {
        powerProfilesControl.isSilent = expanded;

        if (profile === powerProfilesControl.activeProfile) {
            return;
        }
        powerProfilesControl.setProfile(profile);
    }

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    Plasmoid.title: batteryControl.hasBatteries ? i18nd("plasma_applet_org.kde.plasma.battery", "Power & Battery") : i18nd("plasma_applet_org.kde.plasma.battery", "Power Management")

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Plasmoid.status: {
        if (inhibitionControl.isManuallyInhibited || !powerProfilesControl.isInDefaultPowerProfile) {
            return PlasmaCore.Types.ActiveStatus;
        }

        // better-kde-battery: upstream only counts a battery as relevant while
        // it is charging or discharging. Right after plugging in, UPower reports
        // "not charging" for a few seconds, so the system tray hid the icon
        // until charging started. The ring always shows the charge level, so
        // keep it visible whenever there is a battery.
        if (batteryControl.hasInternalBatteries) {
            return PlasmaCore.Types.ActiveStatus;
        }

        return PlasmaCore.Types.PassiveStatus;
    }

    toolTipMainText: {
        if (batteryControl.hasInternalBatteries && !batteryControl.hasCumulative) {
            return i18nd("plasma_applet_org.kde.plasma.battery", "Battery is not present in the bay");
        }

        if (!batteryControl.hasInternalBatteries) {
            return Plasmoid.title
        } else if (batteryControl.isSomehowFullyCharged) {
            return i18nd("plasma_applet_org.kde.plasma.battery", "Fully Charged");
        }

        const percent = batteryControl.percent;
        if (batteryControl.pluggedIn) {
            const state = batteryControl.state;
            if (state === BatteryControlModel.NoCharge) {
                return i18nd("plasma_applet_org.kde.plasma.battery", "Battery at %1%, not Charging", percent);
            } else if (state === BatteryControlModel.Discharging) {
                return i18nd("plasma_applet_org.kde.plasma.battery", "Battery at %1%, plugged in but still discharging", percent);
            } else if (state === BatteryControlModel.Charging) {
                return i18nd("plasma_applet_org.kde.plasma.battery", "Battery at %1%, Charging", percent);
            }
        }
        return i18nd("plasma_applet_org.kde.plasma.battery", "Battery at %1%", percent);
    }

    toolTipSubText: {
        const parts = [];

        // Add special text for the "plugged in but still discharging" case
        if (batteryControl.pluggedIn && batteryControl.state === BatteryControlModel.Discharging) {
            parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "The power supply is not powerful enough to charge the battery"));
        }

        if (!batteryControl.hasBatteries) {
            parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "No Batteries Available"));
        } else if (batteryControl.hasInternalBatteries) {
            if (batteryControl.remainingTime > 0) {
                const remainingTimeString = KCoreAddons.Format.formatDuration(batteryControl.remainingTime, KCoreAddons.FormatTypes.HideSeconds);
                if (batteryControl.state === BatteryControlModel.FullyCharged) {
                    // Don't add anything
                } else if (batteryControl.pluggedIn && batteryControl.state === BatteryControlModel.Charging) {
                    parts.push(i18ndc("plasma_applet_org.kde.plasma.battery", "time until fully charged - HH:MM", "%1 until fully charged", remainingTimeString));
                } else {
                    parts.push(i18ndc("plasma_applet_org.kde.plasma.battery", "remaining time left of battery usage - HH:MM", "%1 remaining", remainingTimeString));
                }
            } else if (batteryControl.state === BatteryControlModel.NoCharge && !batteryControl.isSomehowFullyCharged) {
                parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "Not charging"));
            } // otherwise, don't add anything
        }

        if (inhibitionControl.isManuallyInhibited) {
            parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "Automatic sleep and screen locking are disabled; middle-click to re-enable"));
        } else {
            parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "Middle-click to disable automatic sleep and screen locking"));
        }

        if (powerProfilesControl.isPowerProfileDaemonInstalled) {
            if (powerProfilesControl.isInPerformanceProfile) {
                if (powerProfilesControl.isHeldOnPowerProfile) {
                    parts.push(i18ndp("plasma_applet_org.kde.plasma.battery", "An application has requested activating Performance mode",
                                    "%1 applications have requested activating Performance mode",
                                    powerProfilesControl.profileHolds.length));
                } else {
                    parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "System is in Performance mode; scroll to change"));
                }
            } else if (powerProfilesControl.isInPowersaveProfile) {
                if (powerProfilesControl.isHeldOnPowerProfile) {
                    parts.push(i18ndp("plasma_applet_org.kde.plasma.battery", "An application has requested activating Power Save mode",
                                    "%1 applications have requested activating Power Save mode",
                                    powerProfilesControl.profileHolds.length));
                } else {
                    parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "System is in Power Save mode; scroll to change"));
                }
            } else if (powerProfilesControl.isInBalancedProfile) {
                parts.push(i18nd("plasma_applet_org.kde.plasma.battery", "System is in Balanced Power mode; scroll to change"));
            }
        }

        return parts.join("\n");
    }

    Plasmoid.icon: {
        let iconName;
        if (batteryControl.hasBatteries) {
            iconName = "battery-full";
        } else {
            iconName = "speedometer";
        }

        if (inPanel) {
            return symbolicizeIconName(iconName);
        }

        return iconName;
    }

    compactRepresentation: CompactRepresentation {
        batteryPercent: batteryControl.percent
        batteryPluggedIn: batteryControl.pluggedIn
        hasBatteries: batteryControl.hasBatteries
        hasInternalBatteries: batteryControl.hasInternalBatteries
        hasCumulative: batteryControl.hasCumulative

        isSomehowFullyCharged: batteryControl.isSomehowFullyCharged
        isDischarging: !batteryControl.pluggedIn
        isCharging: batteryControl.state === BatteryControlModel.Charging
        activeProfile: powerProfilesControl.isPowerProfileDaemonInstalled ? powerProfilesControl.activeProfile : ""
        lowBatteryLevel: batterymonitor.lowBatteryLevel

        isManuallyInhibited: inhibitionControl.isManuallyInhibited
        isInDefaultPowerProfile: powerProfilesControl.isInDefaultPowerProfile
        isInPowersaveProfile: powerProfilesControl.isInPowersaveProfile
        isInBalancedProfile: powerProfilesControl.isInBalancedProfile
        isInPerformanceProfile: powerProfilesControl.isInPerformanceProfile

        model: batteryControl

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        property bool wasExpanded: false
        onPressed: wasExpanded = batterymonitor.expanded
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                batterymonitor.inhibitionChangeRequested(!inhibitionControl.isManuallyInhibited);
            } else {
                batterymonitor.expanded = !wasExpanded;
            }
        }

        onWheel: wheel => {
            if (!powerProfilesControl.isPowerProfileDaemonInstalled) {
                return;
            }

            let { profiles } = powerProfilesControl;
            if (profiles.length === 0) {
                return;
            }

            let { activeProfile } = powerProfilesControl;
            let newProfile = activeProfile;

            const delta = (wheel.inverted ? -1 : 1) * (wheel.angleDelta.y ? wheel.angleDelta.y : -wheel.angleDelta.x);
            // Magic number 120 for common "one click"
            // See: https://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
            const steps = Math.round(delta/120);
            const newProfileIndex = Math.max(0, Math.min(profiles.length - 1, profiles.indexOf(activeProfile) + steps));
            batterymonitor.activateProfileRequested(profiles[newProfileIndex])
        }
    }

    fullRepresentation: PopupDialog {
        id: dialogItem

        readonly property var pmControl: inhibitionControl

        Layout.minimumWidth: (batterymonitor.inPanel && !batterymonitor.compactInPanel) ? -1 : Kirigami.Units.gridUnit * 10
        Layout.maximumWidth: Kirigami.Units.gridUnit * 80
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20

        Layout.minimumHeight: (batterymonitor.inPanel && !batterymonitor.compactInPanel) ? -1 : Kirigami.Units.gridUnit * 10
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        Layout.preferredHeight: (batterymonitor.inPanel && !batterymonitor.compactInPanel) ? -1 : implicitHeight

        model: batteryControl

        isManuallyInhibited: inhibitionControl.isManuallyInhibited
        isManuallyInhibitedError: inhibitionControl.isManuallyInhibitedError
        pluggedIn: batteryControl.pluggedIn
        chargeStopThreshold: batteryControl.chargeStopThreshold
        remainingTime: batteryControl.remainingTime
        activeProfile: powerProfilesControl.activeProfile
        activeProfileError: powerProfilesControl.profileError
        requestedInhibitions: inhibitionControl.requestedInhibitions
        inhibitsLidAction: inhibitionControl.isLidPresent && !inhibitionControl.triggersLidAction
        profilesInstalled: powerProfilesControl.isPowerProfileDaemonInstalled
        profiles: powerProfilesControl.profiles
        inhibitionReason: powerProfilesControl.inhibitionReason
        degradationReason: powerProfilesControl.degradationReason
        profileHolds: powerProfilesControl.profileHolds
        isTlpInstalled: powerProfilesControl.isTlpInstalled

        onActivateProfileRequested: profile => {
            batterymonitor.activateProfileRequested(profile);
        }

        onInhibitionChangeRequested: inhibit => {
            batterymonitor.inhibitionChangeRequested(inhibit);
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nd("plasma_applet_org.kde.plasma.battery", "&Show Energy Information…")
            icon.name: "documentinfo"
            visible: batterymonitor.kcmEnergyInformationAuthorized
            onTriggered: checked => KCMUtils.KCMLauncher.openInfoCenter("kcm_energyinfo")
        },
        // better-kde-battery: the percentage is always shown in the ring, so
        // upstream's "Show Battery Percentage on Icon" toggle is gone
        PlasmaCore.Action {
            text: i18nc("@action:inmenu Open the widget's appearance settings", "Customize…")
            icon.name: "document-edit"
            visible: batterymonitor.standardConfigureAction?.enabled ?? false
            onTriggered: checked => batterymonitor.standardConfigureAction.trigger()
        }
    ]

    // better-kde-battery: Plasma's own "Configure…" action, which opens this
    // widget's settings dialog. Upstream replaces it below with an action that
    // opens the Power Management page of System Settings (also used by the
    // configure button in the system tray popup), so keep a reference to the
    // original for "Customize…".
    property QtObject standardConfigureAction: null

    PlasmaCore.Action {
        id: configureAction
        text: i18nd("plasma_applet_org.kde.plasma.battery", "&Configure Power Management…")
        icon.name: "configure"
        onTriggered: checked => {
            KCMUtils.KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig");
        }
    }

    Component.onCompleted: {
        // Must happen before setInternalAction() replaces it (replacing does
        // not delete the original action)
        batterymonitor.standardConfigureAction = Plasmoid.internalAction("configure");

        if (batterymonitor.kcmAuthorized) {
            Plasmoid.setInternalAction("configure", configureAction);
        }
        // better-kde-battery: upstream removes the "configure" action when
        // the Power Management KCM is not authorized, which would also delete
        // the action that opens this widget's own settings. Keep it instead.
    }
}
