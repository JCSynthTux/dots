#!/usr/bin/env python3
import socket, sys, os

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
path = f"/run/user/{os.getuid()}/hypr/{sig}/.socket.sock"

if len(sys.argv) < 2:
    sys.exit(1)

cmd = sys.argv[1]

if cmd == "config-monitor":
    mon, cfg = sys.argv[2], sys.argv[3]
    payload = f"keyword monitor {mon},{cfg}"
elif cmd == "move-workspace":
    ws, mon = sys.argv[2], sys.argv[3]
    payload = f"hl.dsp.workspace.move({{workspace = {ws}, monitor = \"{mon}\"}})"
elif cmd == "raw":
    payload = sys.argv[2]
else:
    payload = cmd

s = socket.socket(socket.AF_UNIX)
s.connect(path)
s.send((payload + "\n").encode())
s.shutdown(socket.SHUT_WR)
s.recv(1024)
s.close()
