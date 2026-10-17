#!/bin/sh
set -e

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Cross-platform dotfiles bootstrap script (macOS & Linux)
# - Ensures zsh, git, and curl are installed
# - Sets zsh as the default login shell
# - Installs Oh My Zsh (if missing)
# - Installs chezmoi (if missing)
# - Applies dotfiles with your current zsh configuration & agnoster theme
#
# Usage:
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/anton264/dotfiles/main/install.sh)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

DOTFILES_REPO="anton264"
OS="$(uname -s)"

echo "==> Detecting operating system: ${OS}..."

# Helper for elevated commands
can_sudo() {
  command -v sudo >/dev/null 2>&1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif can_sudo; then
    sudo "$@"
  else
    echo "ERROR: Root privileges required to install system packages. Please run as root or install sudo." >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# 1. Environment & PATH setup
# -----------------------------------------------------------------------------
# Setup local bin path
BINDIR="${HOME}/.local/bin"
mkdir -p "${BINDIR}"
case ":${PATH}:" in
  *:"${BINDIR}":*) ;;
  *) export PATH="${BINDIR}:${PATH}" ;;
esac

# Add Homebrew to PATH if present (macOS & Linuxbrew)
for brew_bin in "/opt/homebrew/bin" "$HOME/homebrew/bin" "/usr/local/bin" "/home/linuxbrew/.linuxbrew/bin"; do
  if [ -x "${brew_bin}/brew" ]; then
    eval "$("${brew_bin}/brew" shellenv)"
    break
  fi
done

# -----------------------------------------------------------------------------
# 2. Ensure zsh, curl, and git are installed
# -----------------------------------------------------------------------------
install_packages_linux() {
  echo "==> Installing prerequisite packages on Linux..."
  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update -y
    run_as_root apt-get install -y zsh curl git
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y zsh curl git
  elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y zsh curl git
  elif command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -Sy --noconfirm zsh curl git
  elif command -v apk >/dev/null 2>&1; then
    run_as_root apk add --no-cache zsh curl git
  elif command -v zypper >/dev/null 2>&1; then
    run_as_root zypper --non-interactive install zsh curl git
  else
    echo "Warning: Unrecognized package manager. Please ensure zsh, curl, and git are installed." >&2
  fi
}

install_packages_macos() {
  echo "==> Checking prerequisites on macOS..."
  if ! command -v git >/dev/null 2>&1; then
    echo "==> Installing Xcode Command Line Tools for git..."
    xcode-select --install || true
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    echo "==> Installing zsh via Homebrew..."
    if command -v brew >/dev/null 2>&1; then
      brew install zsh
    else
      echo "Error: zsh and brew not found. Please install zsh." >&2
      exit 1
    fi
  fi
}

if [ "$OS" = "Darwin" ]; then
  install_packages_macos
elif [ "$OS" = "Linux" ]; then
  if ! command -v zsh >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    install_packages_linux
  fi
fi

# Verify zsh is available
if ! command -v zsh >/dev/null 2>&1; then
  echo "ERROR: zsh could not be installed or found in PATH." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 3. Set zsh as default shell if not already
# -----------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(basename "${SHELL:-}")"

if [ "$CURRENT_SHELL" != "zsh" ]; then
  echo "==> Setting default shell to zsh (${ZSH_PATH})..."
  # Ensure zsh is listed in /etc/shells
  if [ -f /etc/shells ]; then
    if ! grep -Fxq "${ZSH_PATH}" /etc/shells 2>/dev/null; then
      echo "${ZSH_PATH}" | run_as_root tee -a /etc/shells >/dev/null || true
    fi
  fi

  # Attempt chsh without failing the entire script if non-interactive
  if command -v chsh >/dev/null 2>&1; then
    chsh -s "${ZSH_PATH}" "$USER" 2>/dev/null || chsh -s "${ZSH_PATH}" 2>/dev/null || echo "Note: Run 'chsh -s ${ZSH_PATH}' manually if default shell change was skipped."
  fi
fi

# -----------------------------------------------------------------------------
# 4. Install Oh My Zsh (if not already installed)
# -----------------------------------------------------------------------------
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh (unattended)..."
  # RUNZSH=no prevents starting a new shell; KEEP_ZSHRC=yes avoids overwriting existing ~/.zshrc before chezmoi applies
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
  echo "==> Oh My Zsh is already installed at ${HOME}/.oh-my-zsh."
fi

# -----------------------------------------------------------------------------
# 5. Install chezmoi if needed
# -----------------------------------------------------------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "==> chezmoi not found. Installing..."
  if command -v brew >/dev/null 2>&1; then
    brew install chezmoi
  else
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${BINDIR}"
  fi
fi

# -----------------------------------------------------------------------------
# 6. Initialize and apply dotfiles
# -----------------------------------------------------------------------------
echo "==> Initializing and applying chezmoi dotfiles..."
chezmoi init --apply "${DOTFILES_REPO}"

echo ""
echo "======================================================================"
echo "  🎉 Setup complete! Dotfiles applied successfully."
echo "  Theme: agnoster (Oh My Zsh)"
echo "  Note: For agnoster icons to display correctly, use a Nerd Font"
echo "  (e.g. MesloLGS NF, FiraCode Nerd Font) in your terminal."
echo "======================================================================"
