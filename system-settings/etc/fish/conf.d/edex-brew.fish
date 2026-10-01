# Homebrew (installed on first use of `brew`): put its tools on PATH for fish.
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv fish | source
end
