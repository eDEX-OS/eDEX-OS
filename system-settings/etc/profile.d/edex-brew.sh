# shellcheck shell=sh
# Homebrew (installed on first use of `brew`): put its tools on PATH for bash and zsh logins.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
