-- Monitor config for laptop/desktop with USB-C dock support
-- eDP-1 is the built-in laptop display (no HDR)
-- All other monitors (fallback rule) get HDR enabled

hl.monitor({
    output    = "eDP-1",
    mode      = "preferred",
    position  = "auto-right",
    scale     = "auto",
})

hl.monitor({
    output        = "",
    mode          = "highrr",
    position      = "0x0",
    scale         = 1,
    bitdepth      = 10,
    sdrbrightness = 1.2,
    vrr           = 1,
})

local SOCKET = "/home/jchroback/.config/hypr/scripts/hypr-socket.py"

hl.on("monitor.added", function (mon)
    local name = tostring(mon)
    if name ~= "eDP-1" then
        pcall(function()
            for i = 1, 4 do
                hl.exec_cmd(SOCKET .. " move-workspace " .. i .. " " .. name)
            end
        end)
    end
end)
