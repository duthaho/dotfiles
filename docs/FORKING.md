# Forking & Customizing

This repo is a blueprint. Cloning and running `bootstrap.sh` / `bootstrap.ps1` gets you a working setup with your own identity. This doc covers what to do beyond that.

## Identity

Bootstrap prompts once for `git user.name`, `git user.email`, and optional GitHub handle. It writes them to:

- Unix: `~/.gitconfig.local`, `~/.zshrc.local`
- Windows: `~\.gitconfig.local`, `~\.pwsh.local.ps1`

These files are gitignored. To change identity later, edit them directly — no need to re-run bootstrap.

## Personal exports, aliases, paths

Add anything personal to `~/.zshrc.local` (Unix) or `~/.pwsh.local.ps1` (Windows). The tracked configs source these at the very end of their load order, so anything you put there overrides the defaults.

Example (`~/.zshrc.local`):

```zsh
export WORK_DIR="$HOME/work"
alias work="cd $WORK_DIR"
export AWS_PROFILE=staging
```

Secrets that must not be in git go in `~/.env.local`. The tracked `.zshrc` sources it with `set -a` so every line becomes a real environment variable.

## Adding a tool

To version-control a new tool's config:

1. Create a folder named after the tool: `mytool/`.
2. Inside, mirror the path the config would live at under `$HOME`. If the config is at `~/.config/mytool/config.toml`, create `mytool/.config/mytool/config.toml`.
3. Stow it: `./install/stow-modules.sh mytool`.

To make it a default install, add the folder name to the `DEFAULT_MODULES` array in `install/stow-modules.sh` (Unix) or to `$WinDefaults` in `bootstrap.ps1` (Windows).

## Removing modules

Unix:

```bash
./install/stow-modules.sh --remove zsh   # un-symlinks ~/.zshrc, etc.
```

Windows:

```powershell
.\install\symlink-windows.ps1 -Modules @('pwsh') -Remove
```

Deleting the module folder from the repo also works, but the symlinks under `$HOME` stay broken until you un-stow first.

## Pre-existing files on Windows

If you've used Windows for a while, real files probably already exist where the tracked configs want to live — `~/.gitconfig` is the common case, and Windows Terminal auto-creates `settings.json` on first launch. The helper handles this automatically: when a real (non-symlink) file blocks a target path, it's renamed to `<path>.bak` and the symlink is created. You'll see output like:

```
==> wt
  ~ C:\...\settings.json (real file → C:\...\settings.json.bak, then linking)
```

After install, `.bak` files sit next to the new symlinks. Inspect them with `git diff` (for `.gitconfig.bak`) or just delete them once you're sure nothing was lost.

**Re-runs:** if bootstrap runs again and a new conflict appears, the existing `.bak` is overwritten with the latest pre-install state. To preserve older backups, rename them yourself (`Move-Item .gitconfig.bak .gitconfig.bak.20260523`) between runs.

**One caveat for `.gitconfig` specifically:** the tracked `.gitconfig` includes `~/.gitconfig.local` for identity, so after the symlink is created your identity continues to resolve through the sidecar (which the bootstrap's seed-identity step populates before symlinking). The pre-install `~/.gitconfig` likely has a duplicate `[user]` block — that's fine, it's preserved in `.gitconfig.bak` and the new sidecar is the source of truth going forward.

## Removing Oh My Zsh

If you prefer plain zsh or a leaner manager:

1. Delete the `# Oh My Zsh` block at the top of `zsh/.zshrc`.
2. Replace the three OMZ plugins (`git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`) with your preferred mechanism — sourcing plugin scripts directly works fine.
3. Optionally remove the OMZ install block from `bootstrap.sh`.

The Starship prompt, aliases, and lazy completions don't depend on Oh My Zsh and continue to work.

## Switching prompt engine

To use Starship on Windows instead of oh-my-posh, or vice versa:

- Replace `pwsh/Documents/PowerShell/profile.d/prompt.ps1` with an `Invoke-Expression (& starship init powershell)` line.
- Adjust the package list in `install/prereqs-windows.ps1`.

## Changing the default branch alias, the default `pull.rebase` setting, etc.

These live in `git/.gitconfig`. Edit the tracked file and commit — the change rolls out to every machine on next `git pull` + bootstrap re-run.

## Updating the LICENSE name

The tracked `LICENSE` lists the original author. If you fork the repo and want to use it under your own name, edit the `Copyright (c) <year> <name>` line directly — the bootstrap script does not touch this file.
