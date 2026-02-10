#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Detect OS ────────────────────────────────────────────────
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        PKG="brew install"
    elif command -v apt-get &>/dev/null; then
        OS="debian"
        PKG="sudo apt-get install -y"
        sudo apt-get update -qq
    elif command -v dnf &>/dev/null; then
        OS="fedora"
        PKG="sudo dnf install -y"
    elif command -v pacman &>/dev/null; then
        OS="arch"
        PKG="sudo pacman -S --noconfirm"
    elif command -v apk &>/dev/null; then
        OS="alpine"
        PKG="sudo apk add"
    else
        err "Unsupported OS"
        exit 1
    fi
    ok "Detected OS: $OS"
}

# ─── Install core tools ──────────────────────────────────────
install_packages() {
    info "Installing core packages..."

    case $OS in
        macos)
            brew install neovim lazygit zsh starship eza bat zoxide fzf \
                         zsh-syntax-highlighting zsh-autosuggestions \
                         git curl wget ripgrep fd
            ;;
        debian)
            $PKG git curl wget unzip zsh ripgrep fd-find tar gzip
            ;;
        fedora)
            $PKG git curl wget unzip zsh ripgrep fd-find tar gzip
            ;;
        arch)
            $PKG git curl wget unzip zsh ripgrep fd tar gzip
            ;;
        alpine)
            $PKG git curl wget unzip zsh ripgrep fd tar gzip bash
            ;;
    esac
    ok "Core packages installed"
}

# ─── Install Neovim (latest) ─────────────────────────────────
install_neovim() {
    if command -v nvim &>/dev/null; then
        ok "Neovim already installed: $(nvim --version | head -1)"
        return
    fi

    info "Installing Neovim..."
    case $OS in
        macos)
            brew install neovim
            ;;
        debian|fedora)
            # Get latest stable appimage
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
            sudo tar -xzf nvim-linux-x86_64.tar.gz -C /opt/
            sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
            rm -f nvim-linux-x86_64.tar.gz
            ;;
        arch)
            sudo pacman -S --noconfirm neovim
            ;;
        alpine)
            sudo apk add neovim
            ;;
    esac
    ok "Neovim installed"
}

# ─── Install LazyVim ─────────────────────────────────────────
install_lazyvim() {
    if [ -d "$HOME/.config/nvim/lua/plugins" ]; then
        warn "Neovim config already exists, skipping LazyVim"
        return
    fi

    info "Installing LazyVim..."

    # Backup existing config
    for dir in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim; do
        [ -d "$dir" ] && mv "$dir" "${dir}.bak.$(date +%s)"
    done

    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git

    # Copy custom LazyVim plugin configs if they exist
    if [ -d "$DOTFILES_DIR/nvim/lua" ]; then
        cp -r "$DOTFILES_DIR/nvim/lua/"* ~/.config/nvim/lua/
    fi

    ok "LazyVim installed"
}

# ─── Install lazygit ──────────────────────────────────────────
install_lazygit() {
    if command -v lazygit &>/dev/null; then
        ok "lazygit already installed"
        return
    fi

    info "Installing lazygit..."
    case $OS in
        macos)
            brew install lazygit
            ;;
        *)
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.44.1")
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            sudo install lazygit /usr/local/bin
            rm -f lazygit lazygit.tar.gz
            ;;
    esac
    ok "lazygit installed"
}

# ─── Install Starship ────────────────────────────────────────
install_starship() {
    if command -v starship &>/dev/null; then
        ok "Starship already installed"
        return
    fi

    info "Installing Starship..."
    case $OS in
        macos)
            brew install starship
            ;;
        *)
            curl -sS https://starship.rs/install.sh | sh -s -- -y
            ;;
    esac
    ok "Starship installed"
}

# ─── Install modern CLI tools ────────────────────────────────
install_modern_tools() {
    info "Installing modern CLI tools (eza, bat, zoxide, fzf)..."
    case $OS in
        macos)
            # Already installed in install_packages
            ;;
        debian)
            # eza
            if ! command -v eza &>/dev/null; then
                sudo mkdir -p /etc/apt/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
                sudo apt-get update -qq && sudo apt-get install -y eza 2>/dev/null || warn "eza install failed, skipping"
            fi
            # bat
            $PKG bat 2>/dev/null || true
            # fzf
            $PKG fzf 2>/dev/null || true
            # zoxide
            if ! command -v zoxide &>/dev/null; then
                curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh 2>/dev/null || warn "zoxide install failed"
            fi
            ;;
        fedora)
            sudo dnf install -y eza bat fzf zoxide 2>/dev/null || warn "Some tools failed to install"
            ;;
        arch)
            sudo pacman -S --noconfirm eza bat fzf zoxide 2>/dev/null || warn "Some tools failed to install"
            ;;
        *)
            warn "Skipping modern tools on $OS — install manually if needed"
            ;;
    esac
    ok "Modern CLI tools done"
}

# ─── Install zsh plugins ─────────────────────────────────────
install_zsh_plugins() {
    info "Installing zsh plugins..."

    ZSH_PLUGIN_DIR="$HOME/.zsh/plugins"
    mkdir -p "$ZSH_PLUGIN_DIR"

    if [ ! -d "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"
    fi

    if [ ! -d "$ZSH_PLUGIN_DIR/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_PLUGIN_DIR/zsh-autosuggestions"
    fi

    ok "zsh plugins installed"
}

# ─── Install Claude Code ─────────────────────────────────────
install_claude_code() {
    if command -v claude &>/dev/null; then
        ok "Claude Code already installed"
        return
    fi

    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed (run 'claude' to authenticate)"
}

# ─── Symlink dotfiles ────────────────────────────────────────
link_dotfiles() {
    info "Linking dotfiles..."

    # zshrc
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

    # starship
    mkdir -p "$HOME/.config"
    ln -sf "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

    # ghostty (only on macOS)
    if [[ "$OS" == "macos" ]]; then
        mkdir -p "$HOME/.config/ghostty"
        ln -sf "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    fi

    ok "Dotfiles linked"
}

# ─── Set zsh as default shell ─────────────────────────────────
set_default_shell() {
    if [ "$SHELL" = "$(which zsh)" ]; then
        ok "zsh is already default shell"
        return
    fi

    info "Setting zsh as default shell..."
    ZSH_PATH=$(which zsh)

    # Add to /etc/shells if not present
    if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi

    chsh -s "$ZSH_PATH" 2>/dev/null || warn "Could not change shell. Run: chsh -s $ZSH_PATH"
    ok "Default shell set to zsh (re-login to apply)"
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Dotfiles Bootstrap Installer     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""

    detect_os
    install_packages
    install_neovim
    install_lazyvim
    install_lazygit
    install_starship
    install_modern_tools
    install_zsh_plugins
    install_claude_code
    link_dotfiles
    set_default_shell

    echo ""
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "${GREEN}  All done! Start a new zsh session:${NC}"
    echo -e "${GREEN}    exec zsh${NC}"
    echo -e "${GREEN}  Then run 'claude' to authenticate.${NC}"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
}

main "$@"
