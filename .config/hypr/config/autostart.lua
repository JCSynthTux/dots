-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("$HOME/.config/hypr/scripts/waybar-launch.sh")
    hl.exec_cmd("$HOME/.config/hypr/scripts/xdg.sh")
    hl.exec_cmd("hyprlauncher -d")
    -- hl.exec_cmd("qs -c noctalia-shell")
    hl.exec_cmd("xhost +SI:localuser:root")
end)
