# macOS packages, installed by install.sh with `brew bundle`.

# Shell + terminal tools
brew "git"
brew "wget"
brew "zsh"
brew "tmux"
brew "starship"
brew "eza"
brew "bat"
brew "zoxide"
brew "fzf"
brew "ripgrep"
brew "fd"
brew "jq"

# Editor (LazyVim needs ripgrep, fd and the tree-sitter CLI)
brew "neovim"
brew "tree-sitter-cli"
brew "lazygit"

# Terminal + font (skip Ghostty if it was installed outside Homebrew)
cask "ghostty" unless File.exist?("/Applications/Ghostty.app")
cask "font-jetbrains-mono-nerd-font"
