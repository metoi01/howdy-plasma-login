#!/usr/bin/env bash
# Undo everything install.sh did.
#
# Usage: sudo ./uninstall.sh [--dry-run]

set -euo pipefail

PAM_DIR="${PAM_DIR:-/etc/pam.d}"
VENDOR_PAM_DIR="${VENDOR_PAM_DIR:-/usr/lib/pam.d}"

MARKER="# added by howdy-plasma-login"
SELINUX_MODULE="howdy-login"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) echo "Usage: sudo $0 [--dry-run]"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if (( ! DRY_RUN )) && [[ $EUID -ne 0 ]]; then
    echo "error: run with sudo: sudo $0" >&2
    exit 1
fi

disable_pam_service() {
    local svc="$1"
    local target="$PAM_DIR/$svc"
    local vendor="$VENDOR_PAM_DIR/$svc"

    [[ -f $target ]] || return 0
    grep -qxF "$MARKER" "$target" || return 0

    info "$svc: removing Howdy line"
    if (( DRY_RUN )); then
        echo "   [dry-run] remove marker + following line from $target"
    else
        local tmp
        tmp="$(mktemp)"
        # Drop the marker line and the single line right after it.
        awk -v m="$MARKER" 'skip { skip=0; next } $0 == m { skip=1; next } { print }' \
            "$target" > "$tmp"
        cat "$tmp" > "$target"
        rm -f "$tmp"
    fi

    # If what's left is identical to the vendor file, drop the /etc copy so the
    # system goes back to following OS updates for this file.
    if (( ! DRY_RUN )) && [[ -f $vendor ]] && cmp -s "$target" "$vendor"; then
        info "$svc: identical to $vendor, removing override"
        rm -f "$target"
    fi
    if [[ -f "$target.howdy-bak" ]]; then
        if (( DRY_RUN )); then
            echo "   [dry-run] rm $target.howdy-bak"
        else
            rm -f "$target.howdy-bak"
        fi
    fi
}

for svc in plasmalogin sddm polkit-1; do
    disable_pam_service "$svc"
done

if command -v semodule >/dev/null 2>&1 && semodule -l 2>/dev/null | grep -qx "$SELINUX_MODULE"; then
    info "SELinux: removing module $SELINUX_MODULE"
    if (( DRY_RUN )); then
        echo "   [dry-run] semodule -r $SELINUX_MODULE"
    else
        semodule -r "$SELINUX_MODULE"
    fi
fi

info "Done. The login screen will ask for your password again after reboot."
