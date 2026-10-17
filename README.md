# 🛠️ Dotfiles (managed with chezmoi)

Personal configuration files managed across **macOS** and **Linux** with [chezmoi](https://www.chezmoi.io/).

- **Shell**: `zsh` with **Oh My Zsh**
- **Theme**: `agnoster`
- **Plugins**: `git`, `kubectl`, `helm`, `minikube`

---

## 🚀 Quick Start (New Machine)

### Option 1: One-liner bootstrap (macOS & Linux)
```bash
sh -c "$(curl -fsLS https://raw.githubusercontent.com/anton264/dotfiles/main/install.sh)"
```
This automated script:
1. Installs `zsh`, `curl`, and `git` via the appropriate package manager (`brew`, `apt`, `dnf`, `pacman`, etc.)
2. Sets `zsh` as your default shell (`chsh`)
3. Installs **Oh My Zsh** (unattended)
4. Installs **chezmoi**
5. Initializes and applies these dotfiles

### Option 2: Manual setup
1. Install chezmoi:
   ```bash
   # macOS (Homebrew)
   brew install chezmoi

   # Linux / alternative
   sh -c "$(curl -fsLS get.chezmoi.io)"
   ```

2. Initialize and apply:
   ```bash
   chezmoi init --apply anton264
   ```
   During initialization, you will be prompted for your Git name and email.

---

## 🎨 Terminal Font (Agnoster Theme)

The `agnoster` theme uses Powerline symbols for git branches and path arrows. For the best visual experience, configure your terminal to use a **[Nerd Font](https://www.nerdfonts.com/)** (e.g., *MesloLGS NF*, *JetBrainsMono Nerd Font*, or *FiraCode Nerd Font*).

---

## 📁 Repository Structure

```text
.
├── .chezmoi.toml.tmpl                          # Prompts for machine-specific values (name, email)
├── .chezmoiignore                              # Files ignored when copying to $HOME
├── Brewfile                                    # Homebrew package list (macOS & Linuxbrew)
├── install.sh                                  # Cross-platform bootstrap script (macOS & Linux)
├── run_once_before_install-oh-my-zsh.sh.tmpl   # Pre-hook: ensures Oh My Zsh is installed
├── run_onchange_after_install-packages.sh.tmpl # Post-hook: runs brew bundle when Brewfile changes
├── dot_gitconfig.tmpl                          # ~/.gitconfig (templated with user name/email)
├── dot_zshrc.tmpl                              # ~/.zshrc (agnoster theme, plugins, homelab aliases)
└── dot_config/
    ├── git/
    │   └── ignore                              # ~/.config/git/ignore (global gitignore)
    └── starship.toml                           # ~/.config/starship.toml (optional prompt settings)
```

---

## ⚡ Daily Workflow Cheat Sheet

| Task | Command |
| :--- | :--- |
| **Add a new file to chezmoi** | `chezmoi add ~/.config/nvim/init.lua` |
| **Add an encrypted file (secrets)** | `chezmoi add --encrypt ~/.ssh/id_ed25519` |
| **Add a file as a template** | `chezmoi add --template ~/.zshrc` |
| **Edit a tracked file** | `chezmoi edit ~/.zshrc` |
| **Preview pending changes** | `chezmoi diff` |
| **Apply pending changes to `$HOME`** | `chezmoi apply` |
| **Pull and apply remote updates** | `chezmoi update` |
| **Navigate to source repo** | `chezmoi cd` |
