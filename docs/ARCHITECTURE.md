# Architecture

The "why" doc — decisions and their rationale.

## Module shape: stow-per-tool

Each tracked tool gets its own folder (`zsh/`, `git/`, `tmux/`, `starship/`, ...). Stow takes the folder's internal tree and mirrors it under `$HOME` using symlinks. This means:

- One folder = one logical unit. Easy to add, remove, or fork a single tool without touching anything else.
- `ls -la ~/.zshrc` always shows where the file lives. No magic.
- Adoption mode (`stow --adopt`) migrates an existing `~/.zshrc` into the repo on first install.

Stow doesn't exist for Windows-native. `install/symlink-windows.ps1` provides the equivalent: walk a module's tree, mirror it under `$HOME` via `New-Item -ItemType SymbolicLink`. ~130 lines, idempotent, refuses to overwrite real files.

## Identity stays out of the repo

Every tracked config is identity-free. `git/.gitconfig` has no `[user]` section. The trick is that it `include`s `~/.gitconfig.local`, a gitignored sidecar that the bootstrap seeds on first install.

The same pattern repeats for zsh (`~/.zshrc.local`) and PowerShell (`~/.pwsh.local.ps1`). Tracked configs hook the sidecars at the end of their load order, so a forker can override anything without touching the repo.

## Two prompts, two platforms

Starship on Unix; oh-my-posh on Windows-native PowerShell. Why two:

- Starship is the de facto Unix prompt — fast, single config, conditional segments. Works fine in PowerShell too, but startup is noticeably slower and a few segments behave inconsistently.
- oh-my-posh is purpose-built for PowerShell and is the standard in the Windows community. The visual output matches Starship closely enough that the dev experience feels continuous.

The visual feel (directory, git branch, conditional language version, command duration when slow, success/error caret) is the same on both.

## No CI in v1

The install matrix is four platforms (macOS, Linux, WSL2, Windows-native). Each runs the bootstrap end-to-end inside a fresh user environment. GitHub Actions can't model Windows Sandbox cleanly, and macOS runners are slow and expensive. The cost-to-value of CI is wrong at this stage.

What we do instead:
- Docker Ubuntu 24.04 image for Linux smoke tests, on-demand.
- Windows Sandbox for Windows smoke tests, on-demand.
- WSL2 inside the dev machine for WSL smoke tests, on-demand.
- macOS verified on the dev host or a fresh user account.

If the repo gains contributors or starts breaking regularly, CI gets added in v1.x. Until then, the smoke-test recipes in [TESTING.md](TESTING.md) are the spec.

## Why nvim is opt-in

Two reasons:

1. Not every forker uses Neovim. VS Code, JetBrains, Helix are all valid choices. The dotfiles framework shouldn't force a 160-line Lua config on someone who'll never use it.
2. The Neovim config installs a plugin manager and LSP servers, which materially extends the bootstrap runtime. Keeping it opt-in means the "I just want shell + git" baseline ships in under three minutes.

The bootstrap asks once. `INSTALL_NVIM=1` or `--with-nvim` skips the prompt for automated installs.

## Why no 1Password CLI in v1

The blog mentions 1Password CLI for secrets. We deliberately don't include it in v1 because:
- 1Password isn't universal — Bitwarden, pass, sops, etc. are common alternatives.
- The CLI has different install paths on every platform.
- `.env.local` covers 90% of secret-management needs and is universally supported.

If a forker uses 1Password, they add `eval "$(op signin)"` to their `~/.zshrc.local`. No repo changes required.

## Why Oh My Zsh, not a leaner alternative

The blog uses Oh My Zsh; we follow it. Reasonable alternatives exist (zinit, antidote, plain zsh) and a forker can swap them out by editing `zsh/.zshrc` and removing the OMZ block. We don't go leaner in v1 because:
- OMZ is well-documented and familiar — forkers who copy this repo can find help.
- The three plugins we use (git, zsh-autosuggestions, zsh-syntax-highlighting) are well-supported by OMZ and have minor warts with other managers.
- The startup overhead is acceptable (~200ms) because of lazy completion loading.

[FORKING.md](FORKING.md) documents removing OMZ as a customization.
