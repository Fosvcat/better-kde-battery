#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 fosvcat
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Extract this project's own strings into po/*.pot, merge them into the
# po/<lang>.po files and compile those into the package.
#
# Strings copied from the upstream applet use
# i18nd("plasma_applet_org.kde.plasma.battery", ...) and are translated by
# the system's existing translations, so they are not extracted here.
#
# Requires gettext (xgettext, msgmerge, msgfmt).
set -euo pipefail

cd "$(dirname "$0")/.."

DOMAIN="plasma_applet_io.github.fosvcat.betterkdebattery"

xgettext --from-code=UTF-8 -C --no-location --no-wrap \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    --package-name=better-kde-battery \
    -o "po/$DOMAIN.pot" \
    package/contents/ui/*.qml package/contents/config/*.qml

for po in po/*.po; do
    lang="$(basename "$po" .po)"
    msgmerge --quiet --no-wrap --update --backup=none "$po" "po/$DOMAIN.pot"
    out="package/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$out"
    msgfmt --check -o "$out/$DOMAIN.mo" "$po"
    echo "compiled $lang"
done
