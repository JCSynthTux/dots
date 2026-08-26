#!/bin/sh
export SSH_AUTH_SOCK="/run/user/1000/ssh-agent.socket"
exec /usr/bin/git "$@"
