-- Persona 3 window look for Hyprland's Lua config. persona-theme installs it as
-- ~/.config/hypr/config/persona_theme.lua; require it after your own decorations.
local P3_CYAN  = "rgba(3fd8ffff)"
local P3_BLUE  = "rgba(1238d6ff)"
local P3_WHITE = "rgba(f2fbffff)"
local P3_NAVY  = "rgba(071648ee)"
local P3_GLOW  = "rgba(3fd8ff77)"

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 3,
        col = {
            active_border = { colors = { P3_CYAN, P3_BLUE, P3_WHITE }, angle = 120 },
            inactive_border = P3_NAVY,
        },
    },
    decoration = {
        rounding = 0,
        dim_inactive = true,
        dim_strength = 0.15,
        blur = { enabled = true, size = 9, passes = 3, vibrancy = 0.4, noise = 0.015 },
        shadow = { enabled = true, range = 26, render_power = 2, color = P3_GLOW, color_inactive = "rgba(00000066)" },
    },
})

-- p3 power menu (only while this theme is active; persona-theme swaps this file)
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd([[sh -c "pgrep -f '^qs -c p3-power' >/dev/null || qs -c p3-power -n -d"]]))

-- p3 daily status screen: SUPER+I opens it, again (or Esc) closes it. It stays resident
-- (hidden, idle) because a cold qs start takes over a second.
hl.bind("SUPER + I", hl.dsp.global("p3status:toggle"))

-- p3 loadout screen (equip audio / power / display / link / focus): SUPER+G, resident too
hl.bind("SUPER + G", hl.dsp.global("p3equip:toggle"))

-- p3 toolkit (ITEM screen: captures, utilities, cleanup, key items): SUPER+U, resident too
hl.bind("SUPER + U", hl.dsp.global("p3items:toggle"))

-- p3 modes (SKILL screen: cast bundles of loadout settings): SUPER+K, resident too
hl.bind("SUPER + K", hl.dsp.global("p3skills:toggle"))

-- p3 app launcher (SOCIAL LINK): SUPER+Space, resident too. Caelestia's launcher moves to
-- SUPER+SHIFT+Space (this file loads after binds.lua, so these win while p3 is active)
hl.unbind("SUPER + Space")
hl.bind("SUPER + Space", hl.dsp.global("p3links:toggle"))
hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd("qs -c caelestia ipc call drawers toggle launcher"))

-- p3 corner clock at login (persona-theme starts it when switching)
hl.on("hyprland.start", function ()
    hl.exec_cmd("qs -c p3-wall -n -d")
    hl.exec_cmd("qs -c p3-player -n -d")
    hl.exec_cmd("qs -c p3-status -n -d")
    hl.exec_cmd("qs -c p3-equip -n -d")
    hl.exec_cmd("qs -c p3-items -n -d")
    hl.exec_cmd("qs -c p3-skills -n -d")
    hl.exec_cmd("qs -c p3-links -n -d")
    hl.exec_cmd("sh -c 'sleep 2; qs -c p3-hud -n -d'")
end)
