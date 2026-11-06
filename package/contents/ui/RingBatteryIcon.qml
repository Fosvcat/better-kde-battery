/*
    SPDX-FileCopyrightText: 2026 fosvcat

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// better-kde-battery: ring battery icon in the style of the Papirus icon theme:
// solid shapes, with the used-up part drawn in the same color at 35% opacity.
//
// - The ring shows the charge level, filling clockwise from the top by
//   default (display modes: ring from 0°, ring from 180°, or a "liquid
//   container" that empties from the top).
// - Ring color shows the battery state: text color normally, positive (green)
//   while charging, negative (red) at or below lowLevel.
// - The number in the middle is the percentage, by default in the ring color.
//   While sleep is manually blocked it can be replaced by a symbol.
// - A small dot, like a notification badge, shows a non-balanced power
//   profile: yellow for power save, blue for performance.
//
// Sizes, colors and modes can be changed through `config` (see
// config/main.xml); the defaults are the values described above.

import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: root

    property bool hasBattery: true
    property int percent: 0
    // Whether to draw the remaining charge in the charging color
    property bool charging: false
    // Percentage at or below which the battery counts as low
    property int lowLevel: 10
    // "", "power-saver", "balanced" or "performance"
    property string powerProfile: ""
    // Sleep and screen locking manually blocked
    property bool sleepBlocked: false

    // The appearance settings: Plasmoid.configuration in the panel, or the
    // not yet applied values in the settings dialog's preview. Any object
    // with the entries of config/main.xml as properties works; missing ones
    // fall back to the defaults below.
    property var config: null
    // Prefix of the setting names in `config`, e.g. "cfg_" for a settings page
    property string configPrefix: ""

    function setting(name, fallback) {
        const value = root.config ? root.config[root.configPrefix + name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }

    function clampedSetting(name, fallback, min, max) {
        return Math.max(min, Math.min(max, Number(setting(name, fallback))));
    }

    // An empty (or not "#rgb" / "#rrggbb" / "#aarrggbb") color setting
    // means "use the default color"
    function colorSetting(name, fallback) {
        const value = String(setting(name, "")).trim();
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value) ? value : fallback;
    }

    readonly property int clampedPercent: Math.max(0, Math.min(100, percent))
    readonly property bool isLow: hasBattery && !charging && clampedPercent <= lowLevel

    // Dark theme if the text is light
    readonly property bool isDarkTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.textColor) === Kirigami.ColorUtils.Light

    // --- Colors ---

    readonly property color filledColor: colorSetting("colorFilled", Kirigami.Theme.textColor)
    readonly property color chargingColor: colorSetting("colorCharging", Kirigami.Theme.positiveTextColor)
    readonly property color lowColor: colorSetting("colorLow", Kirigami.Theme.negativeTextColor)
    readonly property color ringColor: charging ? chargingColor : isLow ? lowColor : filledColor
    // 35% is the opacity Papirus uses for the "empty" part of its battery icons
    readonly property color emptyColor: Qt.alpha(colorSetting("colorEmpty", Kirigami.Theme.textColor),
                                                 clampedSetting("emptyOpacity", 35, 0, 100) / 100)
    readonly property color numberColor: setting("numberFollowsRingColor", true) ? ringColor
                                       : colorSetting("colorNumber", Kirigami.Theme.textColor)

    // The color scheme has no "blue" or "yellow" role, so the defaults are
    // fixed, with darker variants for light themes to keep enough contrast
    readonly property color defaultPerformanceColor: isDarkTheme ? "#5c9df5" : "#1a6ed8"
    readonly property color defaultPowerSaverColor: isDarkTheme ? "#f5c518" : "#b38600"

    // --- Geometry, centered in a square ---

    readonly property real size: Math.min(width, height)
    // At 100%, the outer diameter is 82% of the icon (rounded to half
    // pixels), and never larger than the icon
    readonly property real ringScale: clampedSetting("ringScale", 100, 70, 130) / 100
    readonly property real outerRadius: Math.min(size, Math.round(size * 0.82 * ringScale)) / 2
    // At 100%, the ring is 14.5% of the outer diameter wide
    readonly property real ringWidth: Math.min(outerRadius, Math.max(1, Math.round(outerRadius * 2 * 0.145 * clampedSetting("ringThicknessScale", 100, 70, 130) / 100)))

    // 0: ring starting at 0° (top), 1: ring starting at 180° (bottom),
    // 2: liquid container (fills from the bottom, empties from the top)
    readonly property int displayMode: clampedSetting("displayMode", 0, 0, 2)
    readonly property bool reverseDirection: setting("ringCounterClockwise", false)

    // --- Number ---

    // The number was sized against an earlier, slightly larger ring (86% of
    // the icon). Keep deriving it from that ring's inner diameter so the
    // ring can be resized without changing the digits.
    readonly property real numberReferenceDiameter: {
        const diameter = Math.round(size * 0.86);
        return diameter - 2 * Math.max(2, Math.round(diameter * 0.145));
    }
    readonly property real numberScale: clampedSetting("numberSize", 100, 70, 130) / 100

    // Fixed font sizes instead of shrink-to-fit, so one and two digits look
    // the same size and only "100" gets smaller. A plain binding, so the
    // switch between 99 and 100 happens in the same frame as the text change.
    //
    // Capped so a small or thick ring cannot be overflowed by the number;
    // with the default ring the cap is never reached.
    readonly property real innerDiameter: (outerRadius - ringWidth) * 2
    readonly property int twoDigitPixelSize: Math.max(1, Math.min(Math.round(numberReferenceDiameter * 0.55 * numberScale), Math.floor(innerDiameter * 0.7)))
    readonly property int numberPixelSize: clampedPercent >= 100 ? Math.max(1, Math.min(Math.round(numberReferenceDiameter * 0.45 * numberScale), Math.floor(innerDiameter * 0.6))) : twoDigitPixelSize
    readonly property int numberWeight: [Font.Normal, Font.DemiBold, Font.Bold][clampedSetting("numberWeight", 1, 0, 2)]

    // 0: no change, 1: "-", 2: "*", 3: "!"
    readonly property int sleepBlockedSymbol: sleepBlocked ? clampedSetting("sleepBlockedSymbol", 1, 0, 3) : 0

    // --- Power profile indicator ---

    readonly property bool showProfileIndicator: setting("profileIndicator", true)
        && (powerProfile === "performance" || powerProfile === "power-saver")
    readonly property color profileIndicatorColor: powerProfile === "performance"
        ? colorSetting("colorProfilePerformance", defaultPerformanceColor)
        : colorSetting("colorProfilePowerSaver", defaultPowerSaverColor)
    // Diameter including the transparent gap around the dot. The dot sits in
    // a corner of the icon (outside the ring there is some free space, so
    // its outer edges are flush with the icon, not the ring); at 100% it is
    // as large as it can be while reaching only halfway into the ring.
    //   distance of its center from the ring's center, along the diagonal:
    //     sqrt(2) * (size/2 - d/2)
    //   its inner edge on the ring's center line:
    //     sqrt(2) * (size/2 - d/2) - d/2 = outerRadius - ringWidth/2
    readonly property real profileIndicatorBaseDiameter: 2 * (size * Math.SQRT1_2 - outerRadius + ringWidth / 2) / (Math.SQRT2 + 1)
    readonly property real profileIndicatorDiameter: Math.max(1, profileIndicatorBaseDiameter * clampedSetting("profileIndicatorSize", 100, 70, 130) / 100)
    readonly property real profileIndicatorGap: Math.max(0.5, profileIndicatorDiameter * 0.14)
    // 0: bottom right, 1: top right, 2: bottom left, 3: top left
    readonly property int profileIndicatorPosition: clampedSetting("profileIndicatorPosition", 0, 0, 3)
    // Horizontal and vertical distance of the dot's center from the icon's
    // center: smaller dots shrink around the 100% center (so they still
    // overlap the ring), larger ones grow inwards (so they stay inside the
    // icon)
    readonly property real profileIndicatorOffset: Math.min(size / 2 - profileIndicatorBaseDiameter / 2, size / 2 - profileIndicatorDiameter / 2)
    readonly property real profileIndicatorX: width / 2 + (profileIndicatorPosition >= 2 ? -1 : 1) * profileIndicatorOffset
    readonly property real profileIndicatorY: height / 2 + (profileIndicatorPosition % 2 === 1 ? -1 : 1) * profileIndicatorOffset

    // Drawn with Canvas, which can cut the gap around the indicator out of
    // the ring without GPU shader effects
    Canvas {
        id: ring

        anchors.fill: parent

        // Everything the drawing depends on; repaint when it changes
        readonly property string paintState: [
            root.width, root.height, root.hasBattery, root.clampedPercent,
            root.ringColor, root.emptyColor, root.outerRadius, root.ringWidth,
            root.displayMode, root.reverseDirection,
            root.showProfileIndicator, root.profileIndicatorColor, root.profileIndicatorDiameter,
            root.profileIndicatorGap, root.profileIndicatorX, root.profileIndicatorY,
        ].join("|")
        onPaintStateChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const R = root.outerRadius;
            const lineWidth = root.ringWidth;
            const r = R - lineWidth / 2; // radius of the stroke's center line
            const fraction = root.hasBattery ? root.clampedPercent / 100 : 0;

            ctx.lineWidth = lineWidth;
            ctx.lineCap = "butt";

            function strokeArc(color, from, to, anticlockwise) {
                ctx.strokeStyle = color;
                ctx.beginPath();
                ctx.arc(cx, cy, r, from, to, anticlockwise);
                ctx.stroke();
            }

            if (root.displayMode === 2) {
                // Liquid container: the level is a horizontal line, rising
                // from the bottom of the ring (0%) to its top (100%)
                const level = cy + R - 2 * R * fraction;

                ctx.save();
                ctx.beginPath();
                ctx.rect(0, 0, width, level);
                ctx.clip();
                strokeArc(root.emptyColor, 0, 2 * Math.PI, false);
                ctx.restore();

                ctx.save();
                ctx.beginPath();
                ctx.rect(0, level, width, height - level);
                ctx.clip();
                strokeArc(root.ringColor, 0, 2 * Math.PI, false);
                ctx.restore();
            } else {
                // Angles in radians, 0 = 3 o'clock, clockwise
                const start = root.displayMode === 1 ? Math.PI / 2 : -Math.PI / 2;
                const dir = root.reverseDirection ? -1 : 1;
                const sweep = 2 * Math.PI * fraction;

                if (fraction < 1) {
                    strokeArc(root.emptyColor, start + dir * sweep, start + dir * 2 * Math.PI, dir < 0);
                }
                if (fraction > 0) {
                    strokeArc(root.ringColor, start, start + dir * sweep, dir < 0);
                }
            }

            if (root.showProfileIndicator) {
                const x = root.profileIndicatorX;
                const y = root.profileIndicatorY;

                // Transparent gap around the dot
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(x, y, root.profileIndicatorDiameter / 2, 0, 2 * Math.PI, false);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";

                ctx.fillStyle = root.profileIndicatorColor;
                ctx.beginPath();
                ctx.arc(x, y, Math.max(0.5, root.profileIndicatorDiameter / 2 - root.profileIndicatorGap), 0, 2 * Math.PI, false);
                ctx.fill();
            }
        }
    }

    // Vertical reference: the extent of all digits, measured on the glyphs
    // rather than the line box (which includes room for descenders that
    // digits do not have). Measured on a large copy of the font and scaled
    // down: at the real size (7-8 px) glyph metrics are whole pixels and
    // rendering at fractional scale factors uses differently hinted glyphs,
    // which put the number up to 1.5 px too low.
    TextMetrics {
        id: digitMetrics

        readonly property real referencePixelSize: 200

        font.family: number.font.family
        font.weight: number.font.weight
        font.pixelSize: referencePixelSize
        font.features: { "tnum": 1 }
        text: "0123456789"
    }

    Text {
        id: number

        // Center of the digits relative to the baseline, as a fraction of
        // the font size (negative: above the baseline)
        readonly property real digitCenterRatio: (digitMetrics.tightBoundingRect.y + digitMetrics.tightBoundingRect.height / 2) / digitMetrics.referencePixelSize

        // Horizontal: tabular (equal-width) digits centered as a block, so the
        // boundary between two digits is always exactly on the center line,
        // no matter how much ink each digit has (e.g. "61").
        x: 0
        width: root.width
        horizontalAlignment: Text.AlignHCenter

        // Vertical: center of the digits on the center of the ring. Not
        // rounded: the renderer snaps the baseline to physical pixels itself,
        // and rounding to logical pixels is wrong at fractional scale factors.
        y: root.height / 2 - digitCenterRatio * font.pixelSize - baselineOffset

        visible: root.hasBattery && root.sleepBlockedSymbol === 0 && root.setting("showNumber", true)
        text: root.clampedPercent
        color: root.numberColor

        font.weight: root.numberWeight
        font.pixelSize: root.numberPixelSize
        font.features: { "tnum": 1 }
        textFormat: Text.PlainText
    }

    // Size with the same parity as the icon, so a centered item starts on a
    // whole pixel and is not shifted by half a pixel when snapped to the grid
    function sameParity(desired: real, container: real): real {
        return container - 2 * Math.floor((container - desired) / 2);
    }

    // Sleep blocked: "-"
    Rectangle {
        id: dash

        anchors.centerIn: parent
        // About as wide as two digits' strokes, as thick as a digit stroke
        width: root.sameParity(Math.max(3, Math.round(root.numberReferenceDiameter * 0.42 * root.numberScale)), root.width)
        height: root.sameParity(Math.max(1, Math.round(root.twoDigitPixelSize * 0.15)), root.height)
        radius: height / 2
        antialiasing: true

        visible: root.sleepBlockedSymbol === 1
        color: root.numberColor
    }

    // Sleep blocked: "*" or "!", centered on the symbol's own glyph
    TextMetrics {
        id: symbolMetrics

        readonly property real referencePixelSize: 200

        font.family: symbol.font.family
        font.weight: symbol.font.weight
        font.pixelSize: referencePixelSize
        text: symbol.text
    }

    Text {
        id: symbol

        readonly property rect glyphRect: symbolMetrics.tightBoundingRect
        readonly property real glyphScale: font.pixelSize / symbolMetrics.referencePixelSize

        x: root.width / 2 - (glyphRect.x + glyphRect.width / 2) * glyphScale
        y: root.height / 2 - baselineOffset - (glyphRect.y + glyphRect.height / 2) * glyphScale

        visible: root.sleepBlockedSymbol >= 2
        text: root.sleepBlockedSymbol === 2 ? "*" : "!"
        color: root.numberColor

        font.weight: root.numberWeight
        // An asterisk is much smaller than a digit at the same font size
        font.pixelSize: Math.max(1, Math.round(root.twoDigitPixelSize * (root.sleepBlockedSymbol === 2 ? 1.6 : 1)))
        textFormat: Text.PlainText
    }
}
