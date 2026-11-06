#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 fosvcat
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Install or update the widget for the current user.
#
# Use this instead of `kpackagetool6 -u` for updates: kpackagetool6 updates
# by uninstalling and reinstalling, and the running system tray reacts to the
# uninstall by forgetting the widget's settings (it is then disabled, and
# "Always shown" is lost). Copying the files in place keeps them.
#
# Usage: tools/install.sh [--restart]
#   --restart  restart plasmashell afterwards so the new version is loaded
set -euo pipefail

cd "$(dirname "$0")/.."

ID="io.github.fosvcat.betterkdebattery"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$ID"

if [ ! -d "$DEST" ]; then
    kpackagetool6 -t Plasma/Applet -i package
    echo "Installed $ID"
else
    # Replace the installed files in one step, so a running plasmashell never
    # sees a half-copied package
    tmp="$DEST.new.$$"
    rm -rf "$tmp"
    cp -r package "$tmp"
    rm -rf "$DEST.old.$$"
    mv "$DEST" "$DEST.old.$$"
    mv "$tmp" "$DEST"
    rm -rf "$DEST.old.$$"
    echo "Updated $ID in $DEST"
fi

if [ "${1:-}" = "--restart" ]; then
    systemctl --user restart plasma-plasmashell
    echo "Restarted plasmashell"
else
    echo "Restart Plasma to load it: systemctl --user restart plasma-plasmashell"
fi
