-- persona-rice autostart for Hyprland's Lua config (add to your autostart).
hl.on("hyprland.start", function ()
    hl.exec_cmd("caelestia shell -d")
    hl.exec_cmd("qs -c persona-bar -n -d")
end)
