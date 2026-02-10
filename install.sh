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

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"

# ─── Detect OS ────────────────────────────────────────────────
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif command -v apt-get &>/dev/null; then
        OS="debian"
    elif command -v dnf &>/dev/null; then
        OS="fedora"
    elif command -v pacman &>/dev/null; then
        OS="arch"
    elif command -v apk &>/dev/null; then
        OS="alpine"
    else
        err "Unsupported OS"
        exit 1
    fi
    ok "Detected OS: $OS"
}

# ─── Check prerequisites ─────────────────────────────────────
check_prerequisites() {
    if [[ "$OS" == "macos" ]]; then
        info "Installing packages via Homebrew..."
        brew install neovim lazygit zsh starship eza bat zoxide fzf \
                     zsh-syntax-highlighting zsh-autosuggestions \
                     git curl wget ripgrep fd
        ok "Packages installed via Homebrew"
        return
    fi

    info "Checking prerequisites..."
    local missing=()
    for cmd in git curl wget zsh tar gzip unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing prerequisites: ${missing[*]}"
        warn "Install them with your system package manager, e.g.:"
        warn "  sudo apt-get install -y ${missing[*]}"
        warn "  sudo dnf install -y ${missing[*]}"
        warn "  sudo pacman -S ${missing[*]}"
    else
        ok "All prerequisites found"
    fi
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
            # Already installed via Homebrew in check_prerequisites
            ;;
        *)
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
            mkdir -p "$HOME/.local/nvim"
            tar -xzf nvim-linux-x86_64.tar.gz -C "$HOME/.local/" --strip-components=0
            ln -sf "$HOME/.local/nvim-linux-x86_64/bin/nvim" "$LOCAL_BIN/nvim"
            rm -f nvim-linux-x86_64.tar.gz
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
            # Already installed via Homebrew in check_prerequisites
            ;;
        *)
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.44.1")
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            install lazygit "$LOCAL_BIN/"
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
            # Already installed via Homebrew in check_prerequisites
            ;;
        *)
            curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"
            ;;
    esac
    ok "Starship installed"
}

# ─── Install modern CLI tools ────────────────────────────────
install_modern_tools() {
    info "Installing modern CLI tools (eza, bat, zoxide, fzf)..."
    case $OS in
        macos)
            # Already installed via Homebrew in check_prerequisites
            ;;
        *)
            # eza
            if ! command -v eza &>/dev/null; then
                info "Installing eza..."
                EZA_VERSION=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.20.13")
                curl -Lo eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" 2>/dev/null \
                    && tar xf eza.tar.gz \
                    && install eza "$LOCAL_BIN/" \
                    && rm -f eza eza.tar.gz \
                    || warn "eza install failed, skipping"
            fi

            # bat
            if ! command -v bat &>/dev/null; then
                info "Installing bat..."
                BAT_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.24.0")
                curl -Lo bat.tar.gz "https://github.com/sharkdp/bat/releases/latest/download/bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz" 2>/dev/null \
                    && tar xf bat.tar.gz \
                    && install "bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu/bat" "$LOCAL_BIN/" \
                    && rm -rf "bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu" bat.tar.gz \
                    || warn "bat install failed, skipping"
            fi

            # fzf
            if ! command -v fzf &>/dev/null; then
                info "Installing fzf..."
                FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.57.0")
                curl -Lo fzf.tar.gz "https://github.com/junegunn/fzf/releases/latest/download/fzf-${FZF_VERSION}-linux_amd64.tar.gz" 2>/dev/null \
                    && tar xf fzf.tar.gz \
                    && install fzf "$LOCAL_BIN/" \
                    && rm -f fzf fzf.tar.gz \
                    || warn "fzf install failed, skipping"
            fi

            # zoxide
            if ! command -v zoxide &>/dev/null; then
                info "Installing zoxide..."
                curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh 2>/dev/null || warn "zoxide install failed"
            fi
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
    if [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
        ok "zsh is already default shell"
        return
    fi

    if ! command -v zsh &>/dev/null; then
        warn "zsh not found — install it first, then set as default shell"
        return
    fi

    ZSH_PATH=$(which zsh)
    warn "To set zsh as your default shell, run:"
    warn "  sudo chsh -s $ZSH_PATH $USER"
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Dotfiles Bootstrap Installer     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""

    detect_os
    check_prerequisites
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
