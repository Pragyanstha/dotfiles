#!/usr/bin/env bash
# Dotfiles installer for macOS and Linux.
#
# One-liner (clones the repo to ~/dotfiles, then runs this script from there):
#   curl -fsSL https://raw.githubusercontent.com/Pragyanstha/dotfiles/main/install.sh | bash
#
# From a checkout:
#   ~/dotfiles/install.sh
#
# Safe to re-run: existing files are backed up, never deleted.
# Linux without root: everything goes into ~/.local (no sudo needed).
#
# Environment overrides:
#   DOTFILES_DIR     where the repo is cloned       (default: ~/dotfiles)
#   DOTFILES_REPO    git URL to clone               (default: GitHub over HTTPS)
#   DOTFILES_BRANCH  branch to clone                (default: main)

set -eo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/Pragyanstha/dotfiles.git}"
BRANCH="${DOTFILES_BRANCH:-main}"
LOCAL_BIN="$HOME/.local/bin"
NVIM_MIN="0.11.2"   # LazyVim requirement
TMUX_VERSION="3.6a" # built from source on Linux
FZF_MIN="0.48"      # first version with `fzf --zsh`
TS="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"

# ─── Output helpers ──────────────────────────────────────────
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
WARNINGS=()
info() { printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$1"; }
ok()   { printf '%b[OK]%b %s\n' "$GREEN" "$NC" "$1"; }
warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; WARNINGS+=("$1"); }
die()  { printf '%b[ERR]%b %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# version_ge A B → true if version A >= B (compares leading dotted numbers; "3.6a" == "3.6")
version_ge() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        match(a, /[0-9]+(\.[0-9]+)*/); a = substr(a, RSTART, RLENGTH)
        match(b, /[0-9]+(\.[0-9]+)*/); b = substr(b, RSTART, RLENGTH)
        na = split(a, x, "."); nb = split(b, y, "."); n = na > nb ? na : nb
        for (i = 1; i <= n; i++) {
            if (x[i] + 0 > y[i] + 0) exit 0
            if (x[i] + 0 < y[i] + 0) exit 1
        }
        exit 0
    }'
}

cmd_version() {  # cmd_version nvim → "0.12.6" (empty if missing or broken)
    case "$1" in
        nvim) nvim --version 2>/dev/null | sed -n '1s/^NVIM v//p' ;;
        tmux) tmux -V 2>/dev/null | sed -E 's/^tmux (next-)?//' ;;
        fzf)  fzf --version 2>/dev/null | awk '{print $1}' ;;
    esac
    return 0
}

nproc_count() { nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2; }

# ─── Platform detection ──────────────────────────────────────
detect_platform() {
    case "$(uname -s)" in
        Darwin) OS="macos" ;;
        Linux)  OS="linux" ;;
        *) die "Unsupported OS: $(uname -s)" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) die "Unsupported architecture: $(uname -m)" ;;
    esac

    PKG=""
    if [ "$OS" = "linux" ]; then
        [ -f /etc/alpine-release ] && die "Alpine (musl) isn't supported."
        if   have apt-get; then PKG="apt"
        elif have dnf;     then PKG="dnf"
        elif have yum;     then PKG="yum"
        elif have pacman;  then PKG="pacman"
        elif have zypper;  then PKG="zypper"
        fi
    fi

    # Root access is optional: used for system packages and chsh when available.
    SUDO=""
    HAS_ROOT=0
    if [ "$(id -u)" -eq 0 ]; then
        HAS_ROOT=1
    elif have sudo && sudo -n true 2>/dev/null; then
        SUDO="sudo"
        HAS_ROOT=1
    fi

    local mode="user-local (no root)"
    [ "$HAS_ROOT" = 1 ] && mode="root via ${SUDO:-root user}"
    [ "$OS" = "macos" ] && mode="Homebrew"
    ok "Platform: $OS/$ARCH${PKG:+, $PKG}, $mode"
}

# ─── Package managers ────────────────────────────────────────
pkg_install() {  # progress output hidden; errors still show
    case "$PKG" in
        apt)    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@" ;;
        dnf)    $SUDO dnf install -y -q "$@" ;;
        yum)    $SUDO yum install -y -q "$@" ;;
        pacman) $SUDO pacman -S --noconfirm --needed "$@" ;;
        zypper) $SUDO zypper -n -q install "$@" ;;
        *)      return 1 ;;
    esac >/dev/null
}

pkg_refresh() {
    case "$PKG" in
        apt)    $SUDO apt-get update -qq ;;
        pacman) $SUDO pacman -Sy --noconfirm ;;
    esac >/dev/null
}

ensure_homebrew() {
    if ! have brew; then
        for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [ -x "$b" ] && eval "$("$b" shellenv)" && break
        done
    fi
    if ! have brew; then
        info "Installing Homebrew (it may ask for your password)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [ -x "$b" ] && eval "$("$b" shellenv)" && break
        done
    fi
    have brew || die "Homebrew isn't available. Install it from https://brew.sh and re-run."

    # Homebrew doesn't add itself to PATH for future shells; do it once.
    if ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
        # shellcheck disable=SC2016  # literal $(...) for .zprofile
        printf '\neval "$(%s shellenv)"\n' "$(command -v brew)" >> "$HOME/.zprofile"
        ok "Added Homebrew to ~/.zprofile"
    fi
}

# ─── Bootstrap: get the repo, then re-run from it ────────────
ensure_git() {
    if [ "$OS" = "macos" ]; then
        ensure_homebrew  # also installs the Xcode Command Line Tools (git)
        return
    fi
    if ! have git || ! have curl; then
        if [ "$HAS_ROOT" = 1 ] && [ -n "$PKG" ]; then
            info "Installing git and curl..."
            pkg_refresh
            pkg_install git curl ca-certificates
        else
            die "git and curl are required. Ask an admin to install them, e.g.: sudo apt-get install -y git curl"
        fi
    fi
}

bootstrap() {
    DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
    ensure_git

    if [ -d "$DOTFILES_DIR/.git" ]; then
        info "Updating $DOTFILES_DIR..."
        git -C "$DOTFILES_DIR" pull --ff-only -q \
            || warn "Couldn't update $DOTFILES_DIR (local changes?). Using it as-is."
    elif [ -e "$DOTFILES_DIR" ]; then
        die "$DOTFILES_DIR exists but isn't a git checkout. Move it away or set DOTFILES_DIR."
    else
        info "Cloning $REPO_URL into $DOTFILES_DIR..."
        git clone -q --depth 1 --branch "$BRANCH" "$REPO_URL" "$DOTFILES_DIR"
    fi

    [ -f "$DOTFILES_DIR/install.sh" ] || die "No install.sh in $DOTFILES_DIR"
    DOTFILES_REEXEC=1 exec bash "$DOTFILES_DIR/install.sh" "$@"
}

# ─── System packages ─────────────────────────────────────────
install_system_packages() {
    if [ "$OS" = "macos" ]; then
        ensure_homebrew
        info "Installing packages from Brewfile..."
        brew bundle install --no-upgrade --file="$DOTFILES_DIR/Brewfile" \
            || warn "Some Brewfile entries failed (see output above)"
        hash -r
        return
    fi

    if [ "$HAS_ROOT" != 1 ] || [ -z "$PKG" ]; then
        info "No root access: skipping system packages, installing tools into ~/.local"
    else
        info "Installing system packages with $PKG..."
        pkg_refresh || warn "Package index refresh failed"
        local core build extra
        case "$PKG" in
            apt)
                core="git curl ca-certificates tar gzip unzip zsh"
                build="gcc make libc6-dev pkg-config libncurses-dev"
                extra="libevent-dev bison" ;;
            dnf|yum)
                core="git curl tar gzip unzip zsh"
                build="gcc make pkgconfig ncurses-devel"
                extra="libevent-devel bison" ;;
            pacman)
                core="git curl tar gzip unzip zsh"
                build="gcc make pkgconf ncurses"
                extra="libevent bison" ;;
            zypper)
                core="git curl tar gzip unzip zsh"
                build="gcc make pkg-config ncurses-devel"
                extra="libevent-devel bison" ;;
        esac
        # shellcheck disable=SC2086  # word splitting is intended
        pkg_install $core || warn "Failed to install some of: $core"
        # Build tools are only needed for tmux; install_tmux_linux builds
        # ncurses/libevent itself if the distro packages are unavailable.
        # shellcheck disable=SC2086
        pkg_install $build || warn "Failed to install build tools ($build); tmux may not build"
        local p
        for p in $extra; do pkg_install "$p" >/dev/null 2>&1 || true; done
        hash -r
    fi

    local missing=() cmd
    for cmd in git curl tar gzip; do have "$cmd" || missing+=("$cmd"); done
    [ ${#missing[@]} -eq 0 ] || die "Missing required commands: ${missing[*]}"
    have unzip || warn "unzip not found (some Mason LSP installs in Neovim need it)"
}

# ─── Linux: user-local binaries from GitHub releases ─────────
# Latest release tag without hitting the rate-limited GitHub API.
gh_latest_tag() {
    local url
    url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")" || return 1
    case "$url" in */tag/*) echo "${url##*/tag/}" ;; *) return 1 ;; esac
}

# gh_install <owner/repo> <asset> <binary> <tag>: download a release asset and
# put <binary> from it into ~/.local/bin.
gh_install() {
    local repo="$1" asset="$2" bin="$3" tag="$4"
    local dir="$TMP_DIR/$bin"
    rm -rf "$dir" && mkdir -p "$dir/x"
    curl -fsSL "https://github.com/$repo/releases/download/$tag/$asset" -o "$dir/$asset" || return 1
    case "$asset" in
        *.tar.gz) tar -xzf "$dir/$asset" -C "$dir/x" ;;
        *.gz)     gunzip -c "$dir/$asset" > "$dir/x/$bin" ;;
    esac
    local found
    found="$(find "$dir/x" -type f -name "$bin" | head -1)"
    [ -n "$found" ] || return 1
    cp "$found" "$LOCAL_BIN/$bin" && chmod 755 "$LOCAL_BIN/$bin"
}

install_linux_tool() {
    local name="$1" bin tag ver repo asset
    local a="$ARCH"  # x86_64 | aarch64
    case "$name" in
        lazygit)     repo="jesseduffield/lazygit"; bin="lazygit" ;;
        eza)         repo="eza-community/eza";    bin="eza" ;;
        bat)         repo="sharkdp/bat";           bin="bat" ;;
        fzf)         repo="junegunn/fzf";          bin="fzf" ;;
        ripgrep)     repo="BurntSushi/ripgrep";    bin="rg" ;;
        fd)          repo="sharkdp/fd";            bin="fd" ;;
        zoxide)      repo="ajeetdsouza/zoxide";    bin="zoxide" ;;
        starship)    repo="starship/starship";     bin="starship" ;;
        tree-sitter) repo="tree-sitter/tree-sitter"; bin="tree-sitter" ;;
    esac

    if have "$bin"; then
        if [ "$name" != "fzf" ] || version_ge "$(cmd_version fzf)" "$FZF_MIN"; then
            return 0
        fi
    fi

    tag="$(gh_latest_tag "$repo")" || { warn "$name: couldn't find latest release"; return 0; }
    ver="${tag#v}"
    case "$name" in
        lazygit)     asset="lazygit_${ver}_linux_$([ "$a" = aarch64 ] && echo arm64 || echo x86_64).tar.gz" ;;
        eza)         asset="eza_${a}-unknown-linux-$([ "$a" = aarch64 ] && echo gnu || echo musl).tar.gz" ;;
        bat)         asset="bat-${tag}-${a}-unknown-linux-musl.tar.gz" ;;
        fzf)         asset="fzf-${ver}-linux_$([ "$a" = aarch64 ] && echo arm64 || echo amd64).tar.gz" ;;
        ripgrep)     asset="ripgrep-${tag}-${a}-unknown-linux-musl.tar.gz" ;;
        fd)          asset="fd-${tag}-${a}-unknown-linux-musl.tar.gz" ;;
        zoxide)      asset="zoxide-${ver}-${a}-unknown-linux-musl.tar.gz" ;;
        starship)    asset="starship-${a}-unknown-linux-musl.tar.gz" ;;
        tree-sitter) asset="tree-sitter-linux-$([ "$a" = aarch64 ] && echo arm64 || echo x64).gz" ;;
    esac

    info "Installing $name $ver..."
    if ! gh_install "$repo" "$asset" "$bin" "$tag"; then
        warn "$name: download failed ($asset)"
    elif ! "$LOCAL_BIN/$bin" --version >/dev/null 2>&1; then
        rm -f "$LOCAL_BIN/$bin"
        warn "$name $ver doesn't run here (needs a newer glibc than $(ldd --version 2>/dev/null | awk 'NR==1{print $NF}'))"
    else
        ok "$name $ver → ~/.local/bin/$bin"
    fi
}

install_linux_tools() {
    local t
    for t in lazygit eza bat fzf ripgrep fd zoxide starship tree-sitter; do
        install_linux_tool "$t"
    done
    hash -r
}

install_zsh_linux() {
    have zsh && return 0
    info "zsh not found, installing a static build into ~/.local (romkatv/zsh-bin)..."
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)" \
        -- -q -d "$HOME/.local" -e no; then
        hash -r
        ok "zsh → ~/.local/bin/zsh"
    else
        warn "zsh install failed"
    fi
}

install_neovim_linux() {
    if have nvim && version_ge "$(cmd_version nvim)" "$NVIM_MIN"; then
        ok "Neovim $(cmd_version nvim)"
        return
    fi
    local a="$ARCH"; [ "$a" = "aarch64" ] && a="arm64"
    local dir="$HOME/.local/nvim-linux-$a"
    info "Installing Neovim (latest) into $dir..."
    if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$a.tar.gz" \
            -o "$TMP_DIR/nvim.tar.gz"; then
        rm -rf "$dir"
        tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$HOME/.local"
        ln -sfn "$dir/bin/nvim" "$LOCAL_BIN/nvim"
        hash -r
        if nvim --version >/dev/null 2>&1; then
            ok "Neovim $(cmd_version nvim)"
        else
            warn "Neovim was downloaded but doesn't run here (glibc too old?)"
        fi
    else
        warn "Neovim download failed"
    fi
}

# has_header <cc> <header>: true if the compiler can find the header
has_header() {
    printf '#include <%s>\n' "$2" | "$1" -E -x c -I"$HOME/.local/include" - >/dev/null 2>&1
}

# Builds tmux into ~/.local. Only needs a C compiler and make: ncurses and
# libevent are built locally too if the system lacks them.
install_tmux_linux() {
    local cur=""
    have tmux && cur="$(cmd_version tmux)"
    if [ -n "$cur" ] && version_ge "$cur" "$TMUX_VERSION"; then
        ok "tmux $cur"
        return
    fi

    local cc=""
    have cc && cc="cc"
    [ -z "$cc" ] && have gcc && cc="gcc"
    if [ -z "$cc" ] || ! have make; then
        if [ -z "$cur" ] && [ "$HAS_ROOT" = 1 ] && pkg_install tmux 2>/dev/null; then
            warn "No C compiler to build tmux $TMUX_VERSION; installed distro tmux $(cmd_version tmux)"
        elif [ -n "$cur" ]; then
            warn "Keeping tmux $cur: building $TMUX_VERSION needs a C compiler and make"
        else
            warn "tmux not installed: building it needs a C compiler and make"
        fi
        return
    fi

    info "Building tmux $TMUX_VERSION into ~/.local (takes a minute or two)..."
    local build="$TMP_DIR/tmux-build" jobs prefix="$HOME/.local"
    jobs="$(nproc_count)"
    mkdir -p "$build"

    if ! has_header "$cc" curses.h; then
        info "Building ncurses..."
        local ncv="6.5"
        # Libraries and headers only; terminfo entries come from the system.
        # Non-wide build: tmux only uses it for terminfo and links -lncurses.
        if ! { curl -fsSL "https://ftp.gnu.org/gnu/ncurses/ncurses-$ncv.tar.gz" | tar -xz -C "$build" \
            && (cd "$build/ncurses-$ncv" \
                && ./configure --prefix="$prefix" --without-shared --without-debug --without-ada \
                    --without-cxx --without-cxx-binding --without-manpages --without-progs \
                    --without-tests --disable-widec --enable-overwrite --enable-pc-files \
                    --with-pkg-config-libdir="$prefix/lib/pkgconfig" \
                    --with-default-terminfo-dir=/usr/share/terminfo \
                    --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo:/usr/lib/terminfo" \
                && make -s -j"$jobs" && make -s install.libs install.includes) >/dev/null 2>&1; }; then
            warn "ncurses build failed; tmux not installed"
            return
        fi
    fi

    if ! has_header "$cc" event2/event.h; then
        info "Building libevent..."
        local lev="2.1.12-stable"
        if ! { curl -fsSL "https://github.com/libevent/libevent/releases/download/release-$lev/libevent-$lev.tar.gz" \
                | tar -xz -C "$build" \
            && (cd "$build/libevent-$lev" \
                && ./configure --prefix="$prefix" --disable-shared --disable-openssl --disable-samples -q \
                && make -s -j"$jobs" && make -s install) >/dev/null 2>&1; }; then
            warn "libevent build failed; tmux not installed"
            return
        fi
    fi

    # The release tarball ships a pre-generated parser, so yacc is never run;
    # tell configure not to insist on it.
    local yacc_ok=""
    have bison || have yacc || have byacc || yacc_ok="ac_cv_prog_found_yacc=yes"

    if curl -fsSL "https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz" \
            | tar -xz -C "$build" \
        && (cd "$build/tmux-$TMUX_VERSION" \
            && PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
               CPPFLAGS="-I$prefix/include" \
               LDFLAGS="-L$prefix/lib -Wl,-rpath,$prefix/lib" \
               ./configure --prefix="$prefix" -q $yacc_ok \
            && make -s -j"$jobs" && make -s install) >/dev/null 2>&1; then
        hash -r
        ok "tmux $(cmd_version tmux)"
    else
        warn "tmux $TMUX_VERSION build failed${cur:+ (keeping tmux $cur)}"
    fi
}

# ─── Cross-platform setup ────────────────────────────────────
# link <src> <dst>: symlink, backing up any existing file first.
link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm -f "$dst"                       # stale symlink: nothing to keep
    elif [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        rm -f "$dst"                       # identical copy: nothing to keep
    elif [ -e "$dst" ]; then
        mv "$dst" "$dst.bak.$TS"
        info "Backed up $dst → $dst.bak.$TS"
    fi
    ln -s "$src" "$dst"
}

link_dotfiles() {
    info "Linking dotfiles..."
    link "$DOTFILES_DIR/zsh/.zshrc"             "$HOME/.zshrc"
    link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
    link "$DOTFILES_DIR/.tmux.conf"             "$HOME/.tmux.conf"
    if [ "$OS" = "macos" ]; then
        link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    fi
    ok "Dotfiles linked"
}

# Claude Code rewrites settings.json in place (which breaks symlinks), so copy
# it on first install and afterwards only add keys that are missing.
setup_claude_settings() {
    local src="$DOTFILES_DIR/claude/settings.json" dst="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    [ -L "$dst" ] && [ ! -e "$dst" ] && rm -f "$dst"  # dangling link from an old install

    if [ ! -e "$dst" ]; then
        cp "$src" "$dst" && chmod 600 "$dst"
        ok "Claude Code settings installed"
    elif [ -L "$dst" ]; then
        ok "Claude Code settings already linked"
    elif ! have jq; then
        info "Keeping existing ~/.claude/settings.json (install jq to merge repo defaults)"
    elif jq -e --slurpfile repo "$src" '. as $cur | ($repo[0] * $cur) == $cur' "$dst" >/dev/null 2>&1; then
        ok "Claude Code settings up to date"
    elif jq -s '.[0] * .[1]' "$src" "$dst" > "$TMP_DIR/claude.json" 2>/dev/null; then
        cp "$dst" "$dst.bak.$TS"
        cat "$TMP_DIR/claude.json" > "$dst"   # keeps the file's permissions
        ok "Added missing repo defaults to ~/.claude/settings.json (your values kept)"
    else
        warn "Couldn't parse ~/.claude/settings.json; left it unchanged"
    fi
}

install_zsh_plugins() {
    local dir="$HOME/.zsh/plugins" p
    mkdir -p "$dir"
    for p in zsh-syntax-highlighting zsh-autosuggestions; do
        if [ -d "$dir/$p/.git" ]; then
            git -C "$dir/$p" pull -q --ff-only >/dev/null 2>&1 || true
        else
            git clone -q --depth 1 "https://github.com/zsh-users/$p.git" "$dir/$p" \
                || warn "Failed to clone $p"
        fi
    done
    ok "zsh plugins"
}

install_lazyvim() {
    local cfg="$HOME/.config/nvim" fresh=0
    if [ ! -f "$cfg/lua/config/lazy.lua" ]; then
        info "Installing LazyVim starter..."
        if [ -e "$cfg" ]; then
            # A different Neovim config: keep it and its data, out of the way.
            local d
            for d in "$cfg" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
                if [ -e "$d" ]; then
                    mv "$d" "$d.bak.$TS"
                    info "Backed up $d → $d.bak.$TS"
                fi
            done
        fi
        git clone -q --depth 1 https://github.com/LazyVim/starter "$cfg"
        rm -rf "$cfg/.git"
        fresh=1
    fi

    # Symlink each custom file so edits in ~/dotfiles take effect immediately.
    local f
    while IFS= read -r f; do
        [ "$fresh" = 1 ] && rm -f "$cfg/$f"  # starter template, no need to back up
        link "$DOTFILES_DIR/nvim/$f" "$cfg/$f"
    done < <(cd "$DOTFILES_DIR/nvim" && find . -type f ! -name .DS_Store | sed 's|^\./||')
    ok "LazyVim config linked"

    if [ "$fresh" = 1 ] && have nvim; then
        info "Installing Neovim plugins (first run)..."
        nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 \
            || warn "Plugin pre-install failed; they'll install on first nvim launch"
    fi
}

install_tpm() {
    if ! have tmux; then
        warn "tmux not found; skipping tmux plugins"
        return
    fi
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone -q --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
            || { warn "Failed to clone TPM"; return; }
    fi
    if "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1; then
        ok "tmux plugins"
    else
        warn "tmux plugin install failed (press prefix + I inside tmux)"
    fi
}

install_claude_code() {
    if have claude; then
        ok "Claude Code already installed"
        return
    fi
    info "Installing Claude Code..."
    if curl -fsSL https://claude.ai/install.sh | bash >/dev/null; then
        hash -r
        ok "Claude Code installed (run 'claude' to log in)"
    else
        warn "Claude Code install failed"
    fi
}

# ─── Login shell ─────────────────────────────────────────────
BASHRC_BEGIN="# >>> dotfiles: start zsh >>>"

add_bashrc_zsh_hook() {
    local rc="$HOME/.bashrc"
    if grep -qsF "$BASHRC_BEGIN" "$rc"; then
        ok ".bashrc already starts zsh"
        return
    fi
    cat >> "$rc" <<'EOF'

# >>> dotfiles: start zsh >>>
# No root to chsh, so interactive terminal sessions hand over to zsh.
# Never for `bash -c ...` or non-terminal use (scp, rsync, IDE remotes).
# Skip once with: DOTFILES_NO_ZSH=1 bash
if [[ $- == *i* ]] && [ -t 0 ] && [ -t 1 ] && [ -z "${BASH_EXECUTION_STRING:-}" ] \
    && [ -z "${ZSH_VERSION:-}" ] && [ -z "${DOTFILES_NO_ZSH:-}" ]; then
    _dotfiles_zsh="$(command -v zsh 2>/dev/null || echo "$HOME/.local/bin/zsh")"
    if [ -x "$_dotfiles_zsh" ]; then
        export SHELL="$_dotfiles_zsh"
        exec "$_dotfiles_zsh" -l
    fi
    unset _dotfiles_zsh
fi
# <<< dotfiles: start zsh <<<
EOF
    ok ".bashrc will now start zsh for interactive sessions"
}

set_login_shell() {
    local zsh_path user current
    zsh_path="$(command -v zsh 2>/dev/null)" || { warn "zsh not installed; login shell unchanged"; return; }
    user="$(id -un 2>/dev/null || echo "${USER:-}")"
    if [ "$OS" = "macos" ]; then
        current="$(dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}' || true)"
    else
        current="$(getent passwd "$user" 2>/dev/null | cut -d: -f7 || true)"
    fi
    current="${current:-${SHELL:-}}"

    if [ "${current##*/}" = "zsh" ]; then
        ok "Login shell is zsh"
        return
    fi

    if [ "$OS" = "macos" ]; then
        warn "Login shell is $current. To switch: chsh -s /bin/zsh"
        return
    fi

    if [ "$HAS_ROOT" = 1 ]; then
        if [ -f /etc/shells ] && ! grep -qx "$zsh_path" /etc/shells; then
            # Prefer an equivalent path that's already allowed (e.g. /usr/bin vs /usr/sbin)
            local p
            for p in /usr/bin/zsh /bin/zsh /usr/local/bin/zsh; do
                if [ "$p" -ef "$zsh_path" ] && grep -qx "$p" /etc/shells; then
                    zsh_path="$p"
                    break
                fi
            done
            grep -qx "$zsh_path" /etc/shells || echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null
        fi
        if { have chsh && $SUDO chsh -s "$zsh_path" "$user"; } >/dev/null 2>&1 \
            || { have usermod && $SUDO usermod -s "$zsh_path" "$user"; } >/dev/null 2>&1; then
            ok "Login shell set to $zsh_path"
            return
        fi
    fi
    add_bashrc_zsh_hook
}

# ─── Main ────────────────────────────────────────────────────
main() {
    if [ -z "${DOTFILES_REEXEC:-}" ]; then
        printf '\n%b╔══════════════════════════════════════╗\n' "$BLUE"
        printf '║     Dotfiles Bootstrap Installer     ║\n'
        printf '╚══════════════════════════════════════╝%b\n\n' "$NC"
    fi

    detect_platform

    # Piped from curl (or run outside the repo): clone first, then re-run from the checkout.
    local src="${BASH_SOURCE[0]:-}" script_dir=""
    if [ -n "$src" ] && [ -f "$src" ]; then
        script_dir="$(cd "$(dirname "$src")" && pwd)"
    fi
    if [ -z "$script_dir" ] || [ ! -f "$script_dir/zsh/.zshrc" ]; then
        bootstrap "$@"
    fi
    DOTFILES_DIR="$script_dir"
    info "Using dotfiles in $DOTFILES_DIR"

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    install_system_packages
    if [ "$OS" = "linux" ]; then
        install_zsh_linux
        install_neovim_linux
        install_tmux_linux
        install_linux_tools
    fi
    install_zsh_plugins
    link_dotfiles
    setup_claude_settings
    install_lazyvim
    install_tpm
    install_claude_code
    set_login_shell

    printf '\n%b══════════════════════════════════════\n' "$GREEN"
    printf '  Done! Start a new shell:  exec zsh\n'
    printf "  Then run 'claude' to log in.\n"
    printf '══════════════════════════════════════%b\n' "$NC"
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        printf '\n%bWarnings:%b\n' "$YELLOW" "$NC"
        local w
        for w in "${WARNINGS[@]}"; do printf "  - %s\n" "$w"; done
    fi
    echo
}

# When piped (curl | bash), stdin is the script itself. Give the installer the
# terminal instead so prompts (Homebrew, sudo) work.
if [ ! -t 0 ] && (exec </dev/tty) 2>/dev/null; then
    main "$@" </dev/tty
else
    main "$@"
fi
