# Dotfiles

Pragyan's dotfiles - personal development environment configuration

Terminal setup: Ghostty + tmux + Neovim (LazyVim) + Claude Code + lazygit + Starship

## Quick Install

**On a new machine (macOS or any Linux):**

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh
exec zsh
```

**One-liner for remote servers (no git clone needed):**

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/dotfiles/main/install.sh | bash
```

## What's Included

| Tool | Purpose |
|------|---------|
| **tmux** | Terminal multiplexer (Tokyo Night theme, TPM) |
| **Neovim + LazyVim** | Preconfigured editor (IDE-like) |
| **Claude Code** | AI coding assistant in terminal |
| **claudecode.nvim** | Neovim MCP bridge for Claude Code |
| **lazygit** | Terminal UI for git |
| **Starship** | Minimal, fast prompt |
| **eza** | Better `ls` with icons |
| **bat** | Better `cat` with syntax highlighting |
| **zoxide** | Smarter `cd` (type `z partial-path`) |
| **fzf** | Fuzzy finder for everything |
| **zsh plugins** | Syntax highlighting + autosuggestions |

## Key Shortcuts

### tmux (terminal multiplexer)
- `Ctrl+a` — prefix key
- `prefix v` — split pane vertically
- `prefix s` — split pane horizontally
- `prefix H/J/K/L` — resize panes
- `prefix r` — reload config

### Neovim Window Navigation
- `Ctrl+h/j/k/l` — move between windows (works from terminal mode too)

### LazyVim
- `Space` — leader key (opens command menu)
- `Space gg` — lazygit
- `Space ff` — find files
- `Space sg` — search/grep in project
- `Space e` — file explorer

### Claude Code
- `/vim` — enable vim mode
- `/config` — settings
- `/clear` — clear context
- `Escape` — stop Claude

### Claude Code Neovim Plugin (claudecode.nvim)
- `Space ac` — toggle Claude Code terminal
- `Space ab` — add current buffer as context
- `Space as` (visual) — send selection to Claude Code
- `Space aa` — accept diff
- `Space ad` — deny diff

## Customizing

- Shell: `zsh/.zshrc`
- Prompt: `starship/starship.toml`
- Terminal: `ghostty/config`
- tmux: `.tmux.conf`
- Neovim: `nvim/lua/plugins/` (add LazyVim plugin specs)

## tmux Plugins

| Plugin | Purpose |
|--------|---------|
| **tpm** | Plugin manager |
| **tmux-sensible** | Sensible defaults |
| **tmux-pain-control** | Pane navigation bindings |
| **tmux-yank** | Clipboard copy support |
| **tmux-copycat** | Regex search in scrollback |
| **tokyo-night-tmux** | Tokyo Night Storm theme |
