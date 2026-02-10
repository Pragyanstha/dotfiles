# Dotfiles

Pragyan's dotfiles

Terminal setup: Ghostty + Neovim (LazyVim) + Claude Code + lazygit + Starship

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
| **Neovim + LazyVim** | Preconfigured editor (IDE-like) |
| **Claude Code** | AI coding assistant in terminal |
| **lazygit** | Terminal UI for git |
| **Starship** | Minimal, fast prompt |
| **eza** | Better `ls` with icons |
| **bat** | Better `cat` with syntax highlighting |
| **zoxide** | Smarter `cd` (type `z partial-path`) |
| **fzf** | Fuzzy finder for everything |
| **zsh plugins** | Syntax highlighting + autosuggestions |

## Key Shortcuts

### Ghostty (macOS only)
- `Cmd+D` — vertical split
- `Cmd+Shift+D` — horizontal split
- `Ctrl+h/j/k/l` — navigate panes (vim-style)

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

## Customizing

- Shell: `zsh/.zshrc`
- Prompt: `starship/starship.toml`
- Terminal: `ghostty/config`
- Neovim: `nvim/lua/plugins/` (add LazyVim plugin specs)

## Layout

```
┌──────────────┬──────────────┐
│              │              │
│  Claude Code │   Neovim     │
│              │              │
├──────────────┴──────────────┤
│         Terminal            │
└─────────────────────────────┘
```
