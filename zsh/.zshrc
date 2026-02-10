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
