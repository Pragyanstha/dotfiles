# Dotfiles

Pragyan's dotfiles

Terminal setup: Ghostty + Zellij + Neovim (LazyVim) + Claude Code + lazygit + Starship

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
| **Zellij** | Terminal multiplexer (tabs, sessions) |
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

### Zellij (terminal multiplexer)
- `Alt+t` — new tab
- `Alt+w` — close tab
- `Alt+h/l` — prev/next tab
- `Alt+1-9` — jump to tab by number

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
- Multiplexer: `zellij/config.kdl`
- Neovim: `nvim/lua/plugins/` (add LazyVim plugin specs)

## Layout

```
┌─ Tab 1: claude ─┬─ Tab 2: nvim ─┬─ Tab 3: shell ─┐
│                                                     │
│               Active Tab Content                    │
│                                                     │
└─────────────────────────────────────────────────────┘
```
