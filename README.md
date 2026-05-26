# dotfiles

[![bootstrap](https://github.com/duthaho/dotfiles/actions/workflows/bootstrap.yml/badge.svg)](https://github.com/duthaho/dotfiles/actions/workflows/bootstrap.yml)

Cross-platform dotfiles for macOS, Linux, WSL2, and Windows-native. Stow on Unix, PowerShell symlinks on Windows. Identity stays in gitignored `*.local` sidecars so the repo is safe to fork.

## Install

**macOS / Linux / WSL2:**

```bash
git clone https://github.com/duthaho/dotfiles ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

**Windows-native (PowerShell 7):**

```powershell
git clone https://github.com/duthaho/dotfiles $HOME\.dotfiles
cd $HOME\.dotfiles
.\bootstrap.ps1
```

Bootstrap takes ~5 minutes on a warm package cache, ~15 minutes on a cold one. It asks for three things: `git user.name`, `git user.email`, optional GitHub handle.

## What's inside

| Module     | Purpose                              | Platforms          | Default install |
|------------|--------------------------------------|--------------------|-----------------|
| `zsh`      | Shell config + aliases + lazy compl  | macOS, Linux, WSL  | yes             |
| `git`      | gitconfig + global ignore             | all                | yes             |
| `tmux`     | Terminal multiplexer config           | macOS, Linux, WSL  | yes             |
| `starship` | Cross-shell prompt                    | macOS, Linux, WSL  | yes             |
| `pwsh`     | PowerShell 7 profile + oh-my-posh     | Windows            | yes (Windows)   |
| `wt`       | Windows Terminal settings             | Windows            | yes (Windows)   |
| `nvim`     | Neovim IDE (lazy.nvim + LSP)          | all                | opt-in          |

## Modern CLI cluster

The bootstrap installs these alongside the module configs. They're informational
rows in `doctor.*` (not required), so old machines that haven't been re-bootstrapped
still pass.

| Tool      | Purpose                                       | Wired into                |
|-----------|-----------------------------------------------|---------------------------|
| `zoxide`  | Smart `cd` — fuzzy jumps by frecency          | zsh + pwsh `cd` shim      |
| `atuin`   | SQLite-backed shell history; Ctrl-R picker    | zsh + pwsh `Ctrl-R`       |
| `bat`     | `cat` with syntax highlighting                | zsh `cat` alias           |
| `fd`      | `find` replacement with sensible defaults     | (used directly)           |
| `delta`   | Syntax-highlighted git diff                   | `git/.gitconfig.delta`    |

## OS defaults (opt-in)

Two scripts apply a curated set of OS productivity defaults — key repeat,
file-extension visibility, screenshot folder, smart-quote suppression for
code typing, dark mode on Windows, etc. They are **opt-in** and never run
as part of a normal bootstrap.

```bash
./bootstrap.sh --apply-defaults      # macOS — 23 settings
```

```powershell
.\bootstrap.ps1 -ApplyDefaults       # Windows — 17 settings
```

Each apply writes a snapshot to `~/.dotfiles-defaults-backup/<timestamp>.json`
capturing every key's previous value. Revert any apply with:

```bash
./install/defaults/macos.sh revert ~/.dotfiles-defaults-backup/<file>.json
```

```powershell
.\install\defaults\windows.ps1 revert ~\.dotfiles-defaults-backup\<file>.json
```

`--non-interactive` skips the defaults block entirely, so CI never applies
them. Linux is intentionally out of scope (GNOME/KDE/XFCE differ too much
for a single bundle).

## Verify

```bash
./doctor.sh        # Unix
.\doctor.ps1       # Windows
```

Prints a pass/fail row per assertion. Required rows must all pass; the nvim row is informational.

## License

[MIT](LICENSE).
