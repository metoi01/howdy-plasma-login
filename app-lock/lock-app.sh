#!/usr/bin/env bash
# Make an app's menu launcher ask for face authentication before opening.
#
# Usage:
#   ./lock-app.sh <app-id>            lock an app (e.g. a Flatpak id)
#   ./lock-app.sh --remove <app-id>   undo
#   ./lock-app.sh --list              show locked apps
#
# Works by putting a modified copy of the app's .desktop file in
# ~/.local/share/applications, which overrides the system one.
# Run as your normal user, NOT with sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/howdy-app-lock"
USER_APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
MARKER="X-Howdy-App-Lock=true"

die() { echo "error: $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, without sudo"

find_desktop_file() {
    local id="$1" dir
    local dirs=(
        "$HOME/.local/share/flatpak/exports/share/applications"
        "/var/lib/flatpak/exports/share/applications"
        "/usr/local/share/applications"
        "/usr/share/applications"
    )
    for dir in "${dirs[@]}"; do
        if [[ -f "$dir/$id.desktop" ]]; then
            printf '%s\n' "$dir/$id.desktop"
            return 0
        fi
    done
    return 1
}

refresh_menu() {
    command -v update-desktop-database >/dev/null 2>&1 \
        && update-desktop-database "$USER_APPS" 2>/dev/null || true
    command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true
}

lock_app() {
    local id="${1%.desktop}"
    local src dst="$USER_APPS/$id.desktop"

    if [[ -f $dst ]] && grep -qxF "$MARKER" "$dst"; then
        echo "$id is already locked."
        return 0
    fi
    [[ ! -f $dst ]] || die "$dst already exists and was not made by this tool; not touching it"

    src="$(find_desktop_file "$id")" \
        || die "no launcher found for '$id'. Find the id with: flatpak list --app"

    mkdir -p "$BIN_DIR" "$USER_APPS"
    install -m 0755 "$SCRIPT_DIR/howdy-app-lock" "$WRAPPER"

    # Prefix every Exec= line (main entry and actions) with the wrapper,
    # and drop DBusActivatable, which would let the menu bypass Exec=.
    awk -v w="$WRAPPER" -v m="$MARKER" '
        /^\[Desktop Entry\]/   { print; print m; next }
        /^DBusActivatable=/     { next }
        /^Exec=/                { sub(/^Exec=/, "Exec=" w " "); print; next }
        { print }
    ' "$src" > "$dst"

    refresh_menu
    echo "Locked $id. Opening it from the menu now asks for your face."
}

unlock_app() {
    local id="${1%.desktop}"
    local dst="$USER_APPS/$id.desktop"
    [[ -f $dst ]] && grep -qxF "$MARKER" "$dst" || die "$id is not locked by this tool"
    rm -f "$dst"
    refresh_menu
    echo "Unlocked $id."
}

list_locked() {
    grep -lxF "$MARKER" "$USER_APPS"/*.desktop 2>/dev/null \
        | xargs -r -n1 basename | sed 's/\.desktop$//' || true
}

case "${1:-}" in
    ""|-h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
    --remove)     [[ -n ${2:-} ]] || die "usage: $0 --remove <app-id>"; unlock_app "$2" ;;
    --list)       list_locked ;;
    *)            lock_app "$1" ;;
esac
