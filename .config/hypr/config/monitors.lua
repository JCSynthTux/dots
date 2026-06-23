-- Monitor config for laptop with USB-C dock support
-- eDP-1 is the built-in laptop display
-- External monitors (connected via dock) become primary automatically

hl.monitor({
    output    = "eDP-1",
    mode      = "preferred",
    position  = "0x0",
    scale     = "auto",
})

local SOCKET = "/home/jchroback/.config/hypr/scripts/hypr-socket.py"

hl.on("monitor.added", function (mon)
    local name = tostring(mon)
    if name ~= "eDP-1" then
        pcall(function()
            hl.exec_cmd(SOCKET .. " config-monitor " .. name .. " preferred,0x0,1")
            hl.exec_cmd(SOCKET .. " config-monitor eDP-1 preferred,auto-right,1")
            for i = 1, 4 do
                hl.exec_cmd(SOCKET .. " move-workspace " .. i .. " " .. name)
            end
        end)
    end
end)

hl.on("monitor.removed", function (mon)
    local name = tostring(mon)
    if name ~= "eDP-1" then
        pcall(function()
            hl.exec_cmd(SOCKET .. " config-monitor eDP-1 preferred,0x0,1")
        end)
    end
end)
