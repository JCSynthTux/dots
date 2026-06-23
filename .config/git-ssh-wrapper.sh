#!/bin/sh
export SSH_AUTH_SOCK="/home/jchroback/.bitwarden-ssh-agent.sock"
exec /usr/bin/git "$@"
