# ─── Path ─────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
typeset -U path  # drop duplicate PATH entries

# ─── History ──────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_ignore_dups hist_ignore_space

# ─── Completion ───────────────────────────────────
autoload -Uz compinit && compinit -i

# ─── Plugins ──────────────────────────────────────
for _plugin in zsh-syntax-highlighting zsh-autosuggestions; do
  [[ -r "$HOME/.zsh/plugins/$_plugin/$_plugin.zsh" ]] && source "$HOME/.zsh/plugins/$_plugin/$_plugin.zsh"
done
unset _plugin

# ─── Tools ────────────────────────────────────────
(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[fzf] )) && source <(fzf --zsh 2>/dev/null)

# ─── Aliases ──────────────────────────────────────
# Only shadow standard commands when the replacement is installed.
if (( $+commands[eza] )); then
  alias ls="eza --icons"
  alias ll="eza -la --icons"
  alias tree="eza --tree --icons"
  setopt complete_aliases
  compdef _files ls ll
else
  alias ll="ls -la"
fi
(( $+commands[bat] )) && alias cat="bat"
(( $+commands[nvim] )) && alias vim="nvim"
alias lg="lazygit"
alias tx="tmux"
alias txa="tmux attach -t"
alias txn="tmux new -s"
alias c="clear"
alias cc="claude"
alias sr="sshr"
alias n="nvim"
alias hr="herdr"
alias hrc="herdr --remote pragyan@chelsea"

# Navigation
alias ..="cd .."
alias ...="cd ../.."

# Git
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline --graph"
alias gd="git diff"

# Utilities
alias mk="mkdir -p"
alias ports="lsof -i -P -n | grep LISTEN"
alias myip="curl -s ifconfig.me"
# On Linux, `ip` is the network tool, so only alias it on macOS.
[[ "$OSTYPE" == darwin* ]] && alias ip="curl -s ifconfig.me"

# ─── SSH Pane Reconnect ──────────────────────────
mkdir -p "$HOME/.local/state"

# Track CWD so new SSH panes land in the same directory
_save_cwd() { echo "$PWD" > "$HOME/.local/state/last_dir"; }
chpwd_functions+=(_save_cwd)
_save_cwd

ssh() {
  echo "$@" > "$HOME/.local/state/ssh_target"
  TERM=xterm-256color command ssh "$@"
}

sshr() {
  if [[ -f "$HOME/.local/state/ssh_target" ]]; then
    TERM=xterm-256color command ssh -t $(<"$HOME/.local/state/ssh_target") \
      'cd $(cat ~/.local/state/last_dir 2>/dev/null || echo ~) && exec $SHELL -l'
  else
    echo "No SSH session saved"
  fi
}

# Hint on new shell if there's a saved SSH target
if [[ -f "$HOME/.local/state/ssh_target" ]]; then
  printf "\033[2mSSH: %s — type 'sshr' to reconnect\033[0m\n" "$(cat "$HOME/.local/state/ssh_target")"
fi

# Auto-heal leaked xterm mouse-tracking modes on every prompt
_reset_mouse_modes() {
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _reset_mouse_modes

# ─── Optional, machine-specific ──────────────────
# Google Cloud SDK (Homebrew)
[[ -r /opt/homebrew/share/google-cloud-sdk/path.zsh.inc ]] && source /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
[[ -r /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc ]] && source /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc

# nvm
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Unity CLI
[[ -r "$HOME/.unity/env" ]] && source "$HOME/.unity/env"

# Per-machine extras that shouldn't live in the repo
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

true  # don't start the shell with a failed status from the last check
