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

# ─── Detect OS & Architecture ─────────────────────────────────
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

    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *)
            err "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    ok "Detected OS: $OS ($ARCH)"
}

# ─── Check prerequisites ─────────────────────────────────────
check_prerequisites() {
    if [[ "$OS" == "macos" ]]; then
        info "Installing packages via Homebrew..."
        brew install neovim lazygit tmux zsh starship eza bat zoxide fzf \
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
            local nvim_arch="$ARCH"
            [[ "$ARCH" == "aarch64" ]] && nvim_arch="arm64"
            curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz"
            mkdir -p "$HOME/.local/nvim"
            tar -xzf "nvim-linux-${nvim_arch}.tar.gz" -C "$HOME/.local/" --strip-components=0
            ln -sf "$HOME/.local/nvim-linux-${nvim_arch}/bin/nvim" "$LOCAL_BIN/nvim"
            rm -f "nvim-linux-${nvim_arch}.tar.gz"
            ;;
    esac
    ok "Neovim installed"
}

# ─── Install LazyVim ─────────────────────────────────────────
install_lazyvim() {
    if [ -d "$HOME/.config/nvim/lua/plugins" ]; then
        warn "Neovim config already exists, skipping LazyVim clone"
    else
        info "Installing LazyVim..."

        # Backup existing config
        for dir in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim; do
            [ -d "$dir" ] && mv "$dir" "${dir}.bak.$(date +%s)"
        done

        git clone https://github.com/LazyVim/starter ~/.config/nvim
        rm -rf ~/.config/nvim/.git
    fi

    # Copy custom LazyVim configs (always, so updates are applied)
    if [ -d "$DOTFILES_DIR/nvim/lua" ]; then
        cp -r "$DOTFILES_DIR/nvim/lua/"* ~/.config/nvim/lua/
        ok "Custom LazyVim configs applied"
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
            local lg_arch="x86_64"; [[ "$ARCH" == "aarch64" ]] && lg_arch="arm64"
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${lg_arch}.tar.gz"
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
                local eza_arch="$ARCH"; [[ "$ARCH" == "aarch64" ]] && eza_arch="aarch64"
                curl -Lo eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_${eza_arch}-unknown-linux-gnu.tar.gz" 2>/dev/null \
                    && tar xf eza.tar.gz \
                    && install eza "$LOCAL_BIN/" \
                    && rm -f eza eza.tar.gz \
                    || warn "eza install failed, skipping"
            fi

            # bat
            if ! command -v bat &>/dev/null; then
                info "Installing bat..."
                BAT_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.24.0")
                local bat_arch="$ARCH"; [[ "$ARCH" == "aarch64" ]] && bat_arch="aarch64"
                curl -Lo bat.tar.gz "https://github.com/sharkdp/bat/releases/latest/download/bat-v${BAT_VERSION}-${bat_arch}-unknown-linux-gnu.tar.gz" 2>/dev/null \
                    && tar xf bat.tar.gz \
                    && install "bat-v${BAT_VERSION}-${bat_arch}-unknown-linux-gnu/bat" "$LOCAL_BIN/" \
                    && rm -rf "bat-v${BAT_VERSION}-${bat_arch}-unknown-linux-gnu" bat.tar.gz \
                    || warn "bat install failed, skipping"
            fi

            # fzf
            if ! command -v fzf &>/dev/null; then
                info "Installing fzf..."
                FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.57.0")
                local fzf_arch="amd64"; [[ "$ARCH" == "aarch64" ]] && fzf_arch="arm64"
                curl -Lo fzf.tar.gz "https://github.com/junegunn/fzf/releases/latest/download/fzf-${FZF_VERSION}-linux_${fzf_arch}.tar.gz" 2>/dev/null \
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

# ─── Install tmux (from source for latest version) ──────────
install_tmux() {
    local TMUX_VERSION="3.6a"

    if command -v tmux &>/dev/null; then
        local current_ver
        current_ver="$(tmux -V | awk '{print $2}')"
        if [ "$current_ver" = "$TMUX_VERSION" ]; then
            ok "tmux $TMUX_VERSION already installed"
            return
        fi
        info "tmux $current_ver found, upgrading to $TMUX_VERSION..."
    else
        info "Installing tmux $TMUX_VERSION..."
    fi

    case $OS in
        macos)
            # Already installed via Homebrew in check_prerequisites
            return
            ;;
    esac

    # Build dependencies check
    local missing_deps=()
    for cmd in gcc make autoconf pkg-config; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Missing build tools for tmux: ${missing_deps[*]}"
        warn "Install them with your package manager, then re-run"
        return
    fi

    local build_dir
    build_dir="$(mktemp -d)"
    trap "rm -rf '$build_dir'" RETURN

    # Build libevent locally if not already present
    if ! pkg-config --exists "libevent_core >= 2" 2>/dev/null && \
       ! PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig" pkg-config --exists "libevent_core >= 2" 2>/dev/null; then
        info "Building libevent..."
        local LIBEVENT_VERSION="2.1.12-stable"
        curl -Lso "$build_dir/libevent.tar.gz" \
            "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
        tar xf "$build_dir/libevent.tar.gz" -C "$build_dir"
        (cd "$build_dir/libevent-${LIBEVENT_VERSION}" \
            && ./configure --prefix="$HOME/.local" --disable-shared --quiet \
            && make -j"$(nproc)" --quiet \
            && make install --quiet) || { warn "libevent build failed"; return; }
        ok "libevent built"
    fi

    # Build bison locally if not available
    if ! command -v bison &>/dev/null && ! [ -x "$HOME/.local/bin/bison" ]; then
        info "Building bison..."
        local BISON_VERSION="3.8.2"
        curl -Lso "$build_dir/bison.tar.gz" \
            "https://ftp.gnu.org/gnu/bison/bison-${BISON_VERSION}.tar.gz"
        tar xf "$build_dir/bison.tar.gz" -C "$build_dir"
        (cd "$build_dir/bison-${BISON_VERSION}" \
            && ./configure --prefix="$HOME/.local" --quiet \
            && make -j"$(nproc)" --quiet \
            && make install --quiet) || { warn "bison build failed"; return; }
        ok "bison built"
    fi

    info "Building tmux $TMUX_VERSION..."
    curl -Lso "$build_dir/tmux.tar.gz" \
        "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
    tar xf "$build_dir/tmux.tar.gz" -C "$build_dir"
    (cd "$build_dir/tmux-${TMUX_VERSION}" \
        && PATH="$HOME/.local/bin:$PATH" \
           PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig" \
           CFLAGS="-I$HOME/.local/include" \
           LDFLAGS="-L$HOME/.local/lib -Wl,-rpath,$HOME/.local/lib" \
           ./configure --prefix="$HOME/.local" --quiet \
        && make -j"$(nproc)" --quiet \
        && make install --quiet) || { warn "tmux build failed"; return; }

    ok "tmux $TMUX_VERSION installed"
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

# ─── Install TPM (tmux plugin manager) ──────────────────────
install_tpm() {
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        ok "TPM already installed"
    else
        info "Installing TPM..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        ok "TPM installed"
    fi

    info "Installing tmux plugins via TPM..."
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install failed (tmux may need to be running)"
    ok "tmux plugins done"
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

    # tmux
    ln -sf "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

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
    install_tmux
    install_starship
    install_modern_tools
    install_zsh_plugins
    install_claude_code
    link_dotfiles
    install_tpm
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
