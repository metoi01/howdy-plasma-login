#!/usr/bin/env bash
# howdy-plasma-login: enable Howdy face unlock on the KDE Plasma Login Manager
# login screen (Bazzite, Fedora KDE, Fedora Atomic / Kinoite).
#
# Usage: sudo ./install.sh [--with-polkit] [--dry-run]

set -euo pipefail

# Overridable for testing only.
PAM_DIR="${PAM_DIR:-/etc/pam.d}"
VENDOR_PAM_DIR="${VENDOR_PAM_DIR:-/usr/lib/pam.d}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="# added by howdy-plasma-login"
DEFAULT_LINE="auth       sufficient   pam_howdy.so"
SELINUX_MODULE="howdy-login"

WITH_POLKIT=0
DRY_RUN=0

usage() {
    cat <<EOF
Usage: sudo $0 [options]

Options:
  --with-polkit   Also allow face auth in KDE admin/polkit prompts
                  (needed for the app-lock feature).
  --dry-run       Show what would change, change nothing.
  -h, --help      Show this help.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --with-polkit) WITH_POLKIT=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

run() {
    if (( DRY_RUN )); then
        printf '   [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# --- Pre-flight checks -------------------------------------------------------

if (( ! DRY_RUN )) && [[ $EUID -ne 0 ]]; then
    die "run with sudo: sudo $0 $*"
fi

if ! command -v howdy >/dev/null 2>&1; then
    die "Howdy is not installed. Install it and enroll your face first (sudo howdy add)."
fi

# Reuse the exact Howdy line the system already uses (Howdy 3 uses pam_howdy.so,
# Howdy 2 uses pam_python.so ... pam.py), so we don't guess the module path.
find_howdy_line() {
    local f line
    for f in "$PAM_DIR/sudo" "$PAM_DIR/kde" "$PAM_DIR"/*; do
        [[ -f $f ]] || continue
        line="$(grep -m1 -E '^[[:space:]]*auth[[:space:]].*howdy' "$f" 2>/dev/null || true)"
        if [[ -n $line ]]; then
            printf '%s\n' "$line"
            return
        fi
    done
    printf '%s\n' "$DEFAULT_LINE"
}

HOWDY_LINE="$(find_howdy_line)"
info "Howdy PAM line: $HOWDY_LINE"

# --- PAM ---------------------------------------------------------------------

# Add the Howdy line to the top of a PAM service file. On image-based systems
# the vendor file lives in /usr/lib/pam.d; a copy in /etc/pam.d overrides it.
enable_pam_service() {
    local svc="$1"
    local target="$PAM_DIR/$svc"
    local vendor="$VENDOR_PAM_DIR/$svc"

    local current="$target"
    if [[ ! -f $target ]]; then
        if [[ -f $vendor ]]; then
            current="$vendor"
        else
            warn "$svc: no PAM file found in $PAM_DIR or $VENDOR_PAM_DIR, skipping"
            return 1
        fi
    fi

    if grep -q 'howdy' "$current"; then
        info "$svc: Howdy already enabled, nothing to do"
        return 0
    fi

    if [[ ! -f $target ]]; then
        info "$svc: copying $vendor -> $target"
        run cp -p "$vendor" "$target"
    fi

    if [[ ! -f "$target.howdy-bak" ]]; then
        run cp -p "$target" "$target.howdy-bak"
    fi

    info "$svc: adding Howdy as the first auth method"
    if (( DRY_RUN )); then
        printf '   [dry-run] insert at top of %s:\n     %s\n     %s\n' "$target" "$MARKER" "$HOWDY_LINE"
    else
        local tmp
        tmp="$(mktemp)"
        { printf '%s\n%s\n' "$MARKER" "$HOWDY_LINE"; cat "$target"; } > "$tmp"
        cat "$tmp" > "$target"   # keep original owner, mode and SELinux label
        rm -f "$tmp"
    fi
}

DM_SERVICE=""
if [[ -f $PAM_DIR/plasmalogin || -f $VENDOR_PAM_DIR/plasmalogin ]]; then
    DM_SERVICE="plasmalogin"
elif [[ -f $PAM_DIR/sddm || -f $VENDOR_PAM_DIR/sddm ]]; then
    DM_SERVICE="sddm"
    warn "Plasma Login Manager not found, using SDDM instead"
else
    die "neither plasmalogin nor sddm PAM file found; is this a KDE system?"
fi

enable_pam_service "$DM_SERVICE"

if (( WITH_POLKIT )); then
    enable_pam_service "polkit-1" || true
fi

# --- SELinux -----------------------------------------------------------------

if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    if semodule -l 2>/dev/null | grep -qx "$SELINUX_MODULE"; then
        info "SELinux: module $SELINUX_MODULE already installed"
    else
        info "SELinux: installing $SELINUX_MODULE (lets the login screen use the camera)"
        run semodule -i "$SCRIPT_DIR/selinux/$SELINUX_MODULE.cil"
    fi
else
    info "SELinux not enabled, skipping policy module"
fi

# --- Done --------------------------------------------------------------------

echo
info "Done. Reboot, pick your user, leave the password empty and press Enter."
echo "    If something breaks: Ctrl+Alt+F3, log in with your password, run:"
echo "    sudo $SCRIPT_DIR/uninstall.sh"
