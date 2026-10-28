# Dotfiles

Pragyan's dotfiles - personal development environment configuration

Terminal setup: Ghostty + tmux + Neovim (LazyVim) + Claude Code + lazygit + Starship

## Install

One line, on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/Pragyanstha/dotfiles/main/install.sh | bash
```

This clones the repo to `~/dotfiles`, installs everything, and links the configs. Then:

```bash
exec zsh
claude   # log in
```

Re-run the same command (or `~/dotfiles/install.sh`) any time to update. It's safe to repeat: existing files are moved to `*.bak.<timestamp>`, never deleted.

### What happens on each platform

**macOS**: installs Homebrew if needed, then everything in [`Brewfile`](Brewfile) (CLI tools, Ghostty, JetBrains Mono Nerd Font).

**Linux with root or passwordless sudo**: installs zsh, git, curl and build tools with the system package manager (apt, dnf, yum, pacman or zypper) and makes zsh your login shell.

**Linux without root**: no sudo needed. Everything goes into `~/.local`:

- zsh: a static build from [zsh-bin](https://github.com/romkatv/zsh-bin), if zsh isn't already installed
- Neovim, lazygit, eza, bat, fzf, ripgrep, fd, zoxide, starship, tree-sitter: release binaries from GitHub
- tmux 3.6a: built from source, along with ncurses/libevent if they're missing (needs a C compiler and make; otherwise any existing tmux is kept)
- Since you can't `chsh`, a small block is added to `~/.bashrc` that starts zsh in interactive sessions. Skip it once with `DOTFILES_NO_ZSH=1 bash`, or delete the block between the `dotfiles: start zsh` markers.

If you have sudo with a password, run `sudo -v` first so the installer can use the package manager.

Requires `git` and `curl` (plus `bash`). x86_64 and arm64 are supported; Alpine (musl) isn't.

On distros older than Ubuntu 24.04 (glibc < 2.39), the prebuilt tree-sitter CLI doesn't run on arm64 (on x86_64 it runs but prints a glibc warning), so Neovim can't compile new syntax parsers there. Everything else works; the installer warns about it.

### Options

Set these before `bash` in the one-liner, e.g. `curl -fsSL ... | DOTFILES_DIR=~/src/dotfiles bash`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `~/dotfiles` | Where to clone the repo |
| `DOTFILES_REPO` | this repo (HTTPS) | Clone a fork instead |
| `DOTFILES_BRANCH` | `main` | Branch to clone |

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
| **ripgrep / fd** | Fast search (used by LazyVim pickers) |
| **zsh plugins** | Syntax highlighting + autosuggestions |

## What Gets Linked

| Repo file | Installed to |
|-----------|--------------|
| `zsh/.zshrc` | `~/.zshrc` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `.tmux.conf` | `~/.tmux.conf` |
| `ghostty/config` | `~/.config/ghostty/config` (macOS only) |
| `nvim/lua/**` | `~/.config/nvim/lua/**` (each file, on top of the LazyVim starter) |
| `claude/settings.json` | `~/.claude/settings.json` (copied, see below) |

Claude Code rewrites `settings.json` itself, which would break a symlink. So the installer copies it on first install, and on later runs only adds keys that are missing (your existing values always win; needs `jq`).

## Key Shortcuts

### tmux (terminal multiplexer)
- `Ctrl+a` — prefix key
- `prefix v` — split pane vertically
- `prefix s` — split pane horizontally
- `prefix H/J/K/L` — resize panes
- `prefix r` — reload config

### Ghostty (macOS)
- `Cmd+d` / `Cmd+Shift+d` — split right / down
- `Cmd+h/j/k/l` — move between splits
- `Cmd+Shift+h/j/k/l` — resize splits
- `Cmd+Shift+Enter` — zoom split
- `Cmd+Ctrl+=` — equalize splits
- `Cmd+Shift+w` — close split
- `Ctrl+w` (global) — toggle quick terminal
- `Shift+Enter` — new line (multi-line input in Claude Code)

### Shell aliases
- `cc` — claude, `n` / `vim` — nvim, `lg` — lazygit
- `tx` — tmux, `txn <name>` — new session, `txa <name>` — attach
- `gs` / `ga` / `gc` / `gp` / `gl` / `gd` — git status / add / commit / push / log / diff
- `sr` — reconnect to the last SSH host, landing in the same directory
- `myip` — public IP, `ports` — listening ports

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

- Shell: `zsh/.zshrc`. Put machine-specific settings in `~/.zshrc.local` (not in the repo); it's loaded last.
- Prompt: `starship/starship.toml`
- Terminal: `ghostty/config`
- tmux: `.tmux.conf`
- Neovim: `nvim/lua/plugins/` (add LazyVim plugin specs; re-run the installer to link new files)
- macOS packages: `Brewfile`

## tmux Plugins

| Plugin | Purpose |
|--------|---------|
| **tpm** | Plugin manager |
| **tmux-sensible** | Sensible defaults |
| **tmux-pain-control** | Pane navigation bindings |
| **tmux-yank** | Clipboard copy support |
| **tmux-copycat** | Regex search in scrollback |
| **tokyo-night-tmux** | Tokyo Night Storm theme |
