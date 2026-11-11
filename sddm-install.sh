#!/usr/bin/env bash
# Login screens (SDDM) for every theme in themes/*/sddm.
#   sudo ./sddm-install.sh            install sddm + all login themes + the switch helper
#                                     (does NOT change which login manager starts)
#   sudo ./sddm-install.sh --enable   additionally switch the display manager from greetd to sddm
#   sudo ./sddm-install.sh --revert   switch back to greetd
#
# Each theme lands in /usr/share/sddm/themes/persona-<id>. A picture at
# themes/<id>/sddm/background.png is used as that login background; otherwise the
# theme's default wallpaper is.
#
# So that `persona-theme` can change the login screen without a password, this also installs
# /usr/local/bin/persona-sddm-theme (root-owned; it only accepts an installed persona-* theme
# name and rewrites /etc/sddm.conf.d/persona.conf) plus a sudoers rule allowing just that.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
user=${SUDO_USER:-}

case ${1:-} in
    --revert)
        systemctl disable sddm.service
        systemctl enable -f greetd.service
        echo "reverted: greetd will start on next boot"
        exit 0 ;;
    "" | --enable) ;;
    *) echo "usage: sudo $0 [--enable|--revert]"; exit 2 ;;
esac

pacman -S --needed --noconfirm sddm

install -d /usr/share/sddm/themes
rm -rf /usr/share/sddm/themes/persona # pre-theme-switcher name
for d in "$here"/themes/*/sddm; do
    [[ -f $d/metadata.desktop ]] || continue
    id=$(basename "$(dirname "$d")")
    dst=/usr/share/sddm/themes/persona-$id
    rm -rf "$dst"
    cp -r "$d" "$dst"
    if [[ ! -f $dst/background.png ]]; then
        wall=$(. "$here/themes/$id/theme.sh"; echo "$WALLPAPER")
        cp "$here/themes/$id/wallpapers/$wall" "$dst/background.png"
    fi
    chmod -R a+rX "$dst"
    echo "installed login theme persona-$id"
done

# switch helper
cat >/usr/local/bin/persona-sddm-theme <<'SH'
#!/bin/sh
# persona-rice: point SDDM at an installed persona-* theme. Usage: persona-sddm-theme persona-<id>
set -eu
case "$1" in persona-*) ;; *) echo "not a persona theme" >&2; exit 1 ;; esac
printf '%s' "$1" | grep -Eq '^persona-[a-z0-9-]+$' || { echo "bad name" >&2; exit 1; }
[ -f "/usr/share/sddm/themes/$1/metadata.desktop" ] || { echo "not installed: $1" >&2; exit 1; }
install -d /etc/sddm.conf.d
printf '[General]\nDisplayServer=x11\n\n[Theme]\nCurrent=%s\n' "$1" >/etc/sddm.conf.d/persona.conf
SH
chown root:root /usr/local/bin/persona-sddm-theme
chmod 755 /usr/local/bin/persona-sddm-theme

if [[ -n $user ]]; then
    rule=$(mktemp)
    printf '%s ALL=(root) NOPASSWD: /usr/local/bin/persona-sddm-theme\n' "$user" >"$rule"
    if visudo -cf "$rule" >/dev/null; then
        install -m 440 -o root -g root "$rule" /etc/sudoers.d/persona-sddm-theme
    else
        echo "sudoers rule failed validation; persona-theme will skip the login screen" >&2
    fi
    rm -f "$rule"
fi

# point SDDM at the user's active theme (or p3)
active=p3
if [[ -n $user ]]; then
    home=$(getent passwd "$user" | cut -d: -f6)
    a=$(cat "$home/.local/state/persona-theme/current" 2>/dev/null || true)
    [[ -n $a && -d /usr/share/sddm/themes/persona-$a ]] && active=$a
fi
/usr/local/bin/persona-sddm-theme "persona-$active"
echo "login screen: persona-$active"

if [[ ${1:-} == --enable ]]; then
    systemctl disable greetd.service 2>/dev/null || true
    systemctl enable -f sddm.service
    echo "sddm enabled; takes effect on next boot (greetd left installed for rollback)"
fi
