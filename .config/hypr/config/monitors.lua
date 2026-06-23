-- Monitor config for laptop with USB-C dock support
-- eDP-1 is the built-in laptop display
-- External monitors (connected via dock) become primary automatically

hl.monitor({
    output    = "eDP-1",
    mode      = "preferred",
    position  = "0x0",
    scale     = "auto",
})

hl.on("monitor.added", function (name)
    if name ~= "eDP-1" then
        hl.exec_cmd("hyprctl keyword monitor " .. name .. ",preferred,0x0,1")
        hl.exec_cmd("hyprctl keyword monitor eDP-1,preferred,auto-right,1")
    end
end)

hl.on("monitor.removed", function (name)
    if name ~= "eDP-1" then
        hl.exec_cmd("hyprctl keyword monitor eDP-1,preferred,0x0,1")
    end
end)
