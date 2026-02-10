# ─── Path ─────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ─── History ──────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_ignore_dups hist_ignore_space

# ─── Plugins ──────────────────────────────────────
source "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null
source "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null

# ─── Tools ────────────────────────────────────────
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
source <(fzf --zsh) 2>/dev/null

# ─── Aliases ──────────────────────────────────────
alias ls="eza --icons"
alias ll="eza -la --icons"
alias cat="bat"
alias vim="nvim"
alias lg="lazygit"
alias c="clear"
alias cc="claude"
alias sr="sshr"

# ─── SSH Pane Reconnect ──────────────────────────
mkdir -p "$HOME/.local/state"

# Track CWD so new SSH panes land in the same directory
_save_cwd() { echo "$PWD" > "$HOME/.local/state/last_dir"; }
chpwd_functions+=(_save_cwd)
_save_cwd

ssh() {
  echo "$@" > "$HOME/.local/state/ssh_target"
  command ssh "$@"
}

sshr() {
  if [[ -f "$HOME/.local/state/ssh_target" ]]; then
    command ssh -t $(cat "$HOME/.local/state/ssh_target") \
      'cd $(cat ~/.local/state/last_dir 2>/dev/null || echo ~) && exec $SHELL -l'
  else
    echo "No SSH session saved"
  fi
}

# Hint on new shell if there's a saved SSH target
if [[ -f "$HOME/.local/state/ssh_target" ]]; then
  printf "\033[2mSSH: %s — type 'sshr' to reconnect\033[0m\n" "$(cat "$HOME/.local/state/ssh_target")"
fi
