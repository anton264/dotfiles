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
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y zsh curl git
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
# 3. Set zsh as default shell (non-blocking)
# -----------------------------------------------------------------------------
set_default_shell() {
  ZSH_PATH="$(command -v zsh)"
  TARGET_USER="${USER:-$(id -un)}"

  # Detect current login shell from system database
  CURRENT_LOGIN_SHELL=""
  if [ "$OS" = "Linux" ] && command -v getent >/dev/null 2>&1; then
    CURRENT_LOGIN_SHELL="$(getent passwd "${TARGET_USER}" 2>/dev/null | cut -d: -f7)"
  elif [ "$OS" = "Darwin" ] && command -v dscl >/dev/null 2>&1; then
    CURRENT_LOGIN_SHELL="$(dscl . -read "/Users/${TARGET_USER}" UserShell 2>/dev/null | awk '{print $2}')"
  fi
  [ -z "${CURRENT_LOGIN_SHELL}" ] && CURRENT_LOGIN_SHELL="${SHELL:-}"

  if [ "$(basename "${CURRENT_LOGIN_SHELL}")" = "zsh" ]; then
    echo "==> Default shell is already zsh (${CURRENT_LOGIN_SHELL})."
    return 0
  fi

  echo "==> Setting default shell to zsh (${ZSH_PATH}) for user '${TARGET_USER}'..."

  # Ensure zsh is listed in /etc/shells
  if [ -f /etc/shells ] && ! grep -Fxq "${ZSH_PATH}" /etc/shells 2>/dev/null; then
    echo "${ZSH_PATH}" | run_as_root tee -a /etc/shells >/dev/null 2>&1 || true
  fi

  # 1. On Linux: usermod run with sudo/root modifies /etc/passwd without asking for user password
  if [ "$OS" = "Linux" ] && command -v usermod >/dev/null 2>&1; then
    if run_as_root usermod -s "${ZSH_PATH}" "${TARGET_USER}" 2>/dev/null; then
      echo "==> Successfully updated default shell to zsh via usermod."
      return 0
    fi
  fi

  # 2. On macOS: dscl run with sudo/root updates UserShell directly
  if [ "$OS" = "Darwin" ] && command -v dscl >/dev/null 2>&1; then
    if run_as_root dscl . -create "/Users/${TARGET_USER}" UserShell "${ZSH_PATH}" 2>/dev/null; then
      echo "==> Successfully updated default shell to zsh via dscl."
      return 0
    fi
  fi

  # 3. Try chsh with root/sudo (does not prompt for password)
  if command -v chsh >/dev/null 2>&1; then
    if run_as_root chsh -s "${ZSH_PATH}" "${TARGET_USER}" 2>/dev/null; then
      echo "==> Successfully updated default shell to zsh via root chsh."
      return 0
    fi
  fi

  # 4. Fallback: only attempt user chsh if an interactive terminal is attached
  if [ -t 0 ] && command -v chsh >/dev/null 2>&1; then
    echo "==> Please enter your login password if prompted by chsh:"
    chsh -s "${ZSH_PATH}" || echo "Note: Could not set default shell automatically. Run 'chsh -s ${ZSH_PATH}' manually."
  else
    echo "==> Non-interactive terminal: skipping chsh to prevent hanging."
    echo "    To make zsh your default shell, run: chsh -s ${ZSH_PATH}"
  fi
}

set_default_shell

# -----------------------------------------------------------------------------
# 4. Install Oh My Zsh (if not already installed)
# -----------------------------------------------------------------------------
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh (unattended)..."
  CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
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
echo "==> Initializing chezmoi dotfiles..."
chezmoi init "${DOTFILES_REPO}"

echo "==> Applying dotfiles to home directory..."
chezmoi apply

echo ""
echo "======================================================================"
echo "  🎉 Setup complete! Dotfiles applied successfully."
echo "  Theme: agnoster (Oh My Zsh)"
echo "  Note: For agnoster icons to display correctly, use a Nerd Font"
echo "  (e.g. MesloLGS NF, FiraCode Nerd Font) in your terminal."
echo "======================================================================"
