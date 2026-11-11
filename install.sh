#!/usr/bin/env bash
# Install the rice and apply a theme. Anything a theme will overwrite is backed up first (once).
#   ./install.sh                 everything (Persona 3 theme)
#   ./install.sh [id] --terminal only the terminal: greeting, prompt, fish/fzf colours, kitty palette
#                                (--greeting is an old name for the same thing)
# Afterwards switch any time with:  persona-theme <id>
# Login screen (needs root):        sudo ./sddm-install.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
share=${XDG_DATA_HOME:-$HOME/.local/share}/persona-rice
bin=$HOME/.local/bin
backup="$share/backup-$(date +%Y%m%d-%H%M%S)"
theme=p3
only_terminal=0
for a in "$@"; do
    case $a in
        --terminal | --greeting) only_terminal=1 ;;
        -*) echo "usage: $0 [theme] [--terminal]" >&2; exit 2 ;;
        *) theme=$a ;;
    esac
done
[[ -f $here/themes/$theme/theme.sh ]] || { echo "no theme '$theme' in themes/" >&2; exit 2; }

say() { printf '\e[1;37;41m P \e[0m %s\n' "$*"; }
warn() { printf '\e[1;30;47m ! \e[0m %s\n' "$*"; }

need() { command -v "$1" >/dev/null || missing+=("$1"); }
missing=()
need python3; need fastfetch; need fish
if ((!only_terminal)); then
    need caelestia; need qs; need hyprctl
fi
if ((${#missing[@]})); then
    warn "missing commands: ${missing[*]} (see README for packages)"
    exit 1
fi
if ((!only_terminal)); then
    if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        warn "run this from inside a Hyprland session (or use --terminal)"
        exit 1
    fi
    if [[ ! -d /etc/xdg/quickshell/caelestia ]]; then
        warn "caelestia-shell not found at /etc/xdg/quickshell/caelestia; install it first"
        exit 1
    fi
    families=$(fc-list : family)   # read once: `fc-list | grep -q` trips pipefail via SIGPIPE
    for f in "Jost" "Bebas Neue" "Antonio" "Material Symbols Sharp"; do
        grep -qi "^$f" <<<"$families" || warn "font '$f' not installed; the bar will fall back to a default font"
    done
fi

# ── one-time backup of everything themes overwrite ──────────────────────────────
if [[ ! -e $share/.backed-up ]]; then
    say "backing up existing config to $backup"
    for p in fastfetch/persona.py fastfetch/persona.jsonc fish/conf.d/persona-colors.fish \
        fish/conf.d/persona-greeting.fish starship.toml kitty/themes/persona.conf kitty/kitty.conf \
        caelestia/shell.json caelestia/shell-tokens.json caelestia/persona-scheme.py caelestia/persona-dark.txt \
        quickshell/persona-bar quickshell/caelestia-overlay quickshell/caelestia-patches.py \
        quickshell/sync-caelestia.sh hypr/hyprland.lua hypr/config/persona_theme.lua hypr/persona-theme.conf; do
        if [[ -e $cfg/$p ]]; then
            mkdir -p "$backup/$(dirname "$p")"
            cp -a "$cfg/$p" "$backup/$p"
        fi
    done
    mkdir -p "$share"
    touch "$share/.backed-up"
fi

# ── themes + switcher ───────────────────────────────────────────────────────────
say "themes -> $share/themes"
mkdir -p "$share"
rm -rf "$share/themes"
cp -a "$here/themes" "$share/themes"
rm -f "$share"/themes/*/sddm/background.png   # personal login backgrounds stay in the repo copy
install -Dm755 "$here/shared/persona-theme" "$bin/persona-theme"
case ":$PATH:" in *":$bin:"*) ;; *) warn "$bin is not on your PATH; add it to run persona-theme" ;; esac

# ── media slots (your own art/videos; see README) ───────────────────────────────
media=$share/media/p3
mkdir -p "$media"
if compgen -G "$here/media/p3/*" >/dev/null; then
    say "media -> $media"
    cp -a "$here"/media/p3/. "$media/"
    rm -f "$media/.gitkeep"
fi
# no video wallpaper yet: p3-wall shows this still instead
[[ -e $media/wall-still.png || -e $media/wall.mp4 ]] ||
    cp "$here/themes/p3/wallpapers/p3-depths.png" "$media/wall-still.png"

# ── shared pieces ───────────────────────────────────────────────────────────────
if grep -qs 'fastfetch/persona.py' "$cfg/fish/config.fish"; then
    :   # config.fish already runs the greeting itself
else
    install -Dm644 "$here/shared/fish/persona-greeting.fish" "$cfg/fish/conf.d/persona-greeting.fish"
    if grep -qs 'function fish_greeting' "$cfg/fish/config.fish"; then
        warn "your config.fish defines its own fish_greeting, which overrides this one; remove it to see the greeting"
    fi
fi
if grep -qsE '^\s*set .*(fish_color_|FZF_DEFAULT_OPTS)' "$cfg/fish/config.fish"; then
    warn "your config.fish sets its own fish/fzf colours, which override persona-colors.fish"
fi
if command -v starship >/dev/null; then
    grep -qs 'starship init fish' "$cfg/fish/config.fish" ||
        warn "add 'starship init fish | source' to your config.fish to use the prompt"
else
    warn "starship not installed; the prompt theme is in place for when it is"
fi
if ! grep -qsx 'include themes/persona.conf' "$cfg/kitty/kitty.conf"; then
    # last include wins, so appending overrides any earlier theme without deleting it
    mkdir -p "$cfg/kitty"
    printf '\n# persona-rice terminal palette (persona-theme swaps this file)\ninclude themes/persona.conf\n' >>"$cfg/kitty/kitty.conf"
fi
# Dark Hour recolours kitty through this overlay (written by p3-hud/darkhour.py); it must come last
grep -qsx 'include themes/darkhour-overlay.conf' "$cfg/kitty/kitty.conf" ||
    printf 'include themes/darkhour-overlay.conf\n' >>"$cfg/kitty/kitty.conf"

if ((!only_terminal)); then
    install -Dm755 "$here/shared/sync-caelestia.sh" "$cfg/quickshell/sync-caelestia.sh"

    # register every theme's colour scheme with caelestia-cli (needs sudo, once per scheme)
    schemes=$(python3 -c 'import caelestia, os; print(os.path.join(os.path.dirname(caelestia.__file__), "data/schemes"))' 2>/dev/null || true)
    if [[ -n $schemes && -d $schemes ]]; then
        for t in "$here"/themes/*/; do
            [[ -f $t/caelestia/scheme.txt ]] || continue
            name=$(. "$t/theme.sh"; echo "$SCHEME")
            [[ -n $name ]] || continue
            if ! cmp -s "$t/caelestia/scheme.txt" "$schemes/$name/default/dark.txt"; then
                say "registering scheme '$name' in $schemes (sudo)"
                sudo install -Dm644 "$t/caelestia/scheme.txt" "$schemes/$name/default/dark.txt" ||
                    warn "skipped; the scheme is still applied directly"
            fi
        done
    else
        warn "caelestia python package not found; schemes are applied directly only"
    fi
fi

# ── apply ───────────────────────────────────────────────────────────────────────
if ((only_terminal)); then
    "$bin/persona-theme" "$theme" --terminal
    exit 0
fi
"$bin/persona-theme" "$theme"

cat <<EOF

$(say "done")
  - Switch themes any time:  persona-theme            (list)
                             persona-theme <id>       (apply)
  - Autostart: add shared/hypr/autostart.lua (Lua config) or autostart.conf (hyprland.conf)
    from this repo if Caelestia and persona-bar aren't started already.
  - Login screen: sudo ./sddm-install.sh   (then --enable to switch from greetd)
  - Lock screen avatar: put a square image at ~/.face
  - After every caelestia-shell update run: ~/.config/quickshell/sync-caelestia.sh
  - Backups of anything replaced: $share/backup-*
EOF
