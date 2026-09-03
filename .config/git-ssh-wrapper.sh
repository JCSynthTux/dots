#!/bin/sh
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
exec /usr/bin/git "$@"
