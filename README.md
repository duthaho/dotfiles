# dotfiles

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

## Verify

```bash
./doctor.sh        # Unix
.\doctor.ps1       # Windows
```

Prints a pass/fail row per assertion. Required rows must all pass; the nvim row is informational.

## Forking

See [docs/FORKING.md](docs/FORKING.md). The short version:

- Identity sidecars (`~/.gitconfig.local`, `~/.zshrc.local`, `~/.pwsh.local.ps1`) hold anything personal. They're gitignored.
- Tracked configs are identity-free and safe to share.
- Adding a tool = `mkdir mytool/<target-path>` + `stow mytool`.

## Background

The system this repo implements is documented in two blog posts:

- *My Dotfiles Aren't Aesthetic. They're Operational.* — terminal foundation (this repo's v1 scope).
- *Dotfiles for macOS: From Terminal to Desktop Environment* — desktop layer (out of v1 scope; will land as v1.x+).

## License

[MIT](LICENSE).
