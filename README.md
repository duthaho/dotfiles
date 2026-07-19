# dotfiles

[![bootstrap](https://github.com/duthaho/dotfiles/actions/workflows/bootstrap.yml/badge.svg)](https://github.com/duthaho/dotfiles/actions/workflows/bootstrap.yml)

Cross-platform dotfiles for macOS, Linux/WSL2, and Windows native. `stow` on Unix, PowerShell symlinks on Windows. Identity stays in gitignored `*.local` sidecars so the repo is safe to fork.

## Quickstart

**macOS / Linux / WSL2:**

```bash
git clone https://github.com/duthaho/dotfiles ~/.dotfiles && cd ~/.dotfiles && ./bootstrap.sh
```

**Windows (PowerShell 7):**

```powershell
git clone https://github.com/duthaho/dotfiles $HOME\.dotfiles; cd $HOME\.dotfiles; .\bootstrap.ps1
```

Bootstrap prompts for `git user.name`, `git user.email`, and an optional GitHub handle. ~5 min on a warm package cache, ~15 min cold. Open a fresh shell when it's done.

## Daily commands

After bootstrap, `dot` is the front door — same set of commands on every platform.

```
dot bootstrap [flags]    re-run the full bootstrap (use after a pull that changed packages)
dot doctor               health checks
dot stow <module>        symlink a specific module (e.g., nvim)
dot defaults apply       apply opt-in OS defaults
dot defaults revert <snapshot.json>
                         restore a previous apply
dot update               git pull --ff-only + re-stow default modules (does NOT reinstall packages)
dot uninstall [--dry-run]
                         remove every repo-owned symlink (clean teardown)
dot fork-check [--staged]
                         scan tracked (or staged) files for leaked identity/secrets
dot fork-check --install-hook
                         enable the pre-commit fork-safety hook
dot help                 show usage
```

## What's installed

**Modules** — config bundles symlinked into `$HOME`:

| Module     | Purpose                            | Platforms       | Install |
|------------|------------------------------------|-----------------|---------|
| `zsh`      | shell config, aliases, completions | macOS/Linux/WSL | default |
| `git`      | gitconfig + global ignore          | all             | default |
| `tmux`     | multiplexer config                 | macOS/Linux/WSL | default |
| `starship` | cross-shell prompt                 | macOS/Linux/WSL | default |
| `pwsh`     | PowerShell 7 profile + oh-my-posh  | Windows         | default |
| `wt`       | Windows Terminal settings          | Windows         | default |
| `nvim`     | Neovim (lazy.nvim + LSP)           | all             | opt-in  |
| `kitty`    | kitty terminal emulator config     | macOS/Linux     | default |

**CLI cluster** — installed via the package manifest, wired into the shell:

| Tool     | Why                            | Wired into                |
|----------|--------------------------------|---------------------------|
| `zoxide` | smart `cd` by frecency         | zsh + pwsh `cd` shim      |
| `atuin`  | SQLite shell history (Ctrl-R)  | zsh + pwsh                |
| `bat`    | `cat` with syntax highlighting | zsh `cat` alias           |
| `fd`     | better `find`                  | (used directly)           |
| `delta`  | syntax-highlighted git diffs   | `~/.gitconfig.delta`      |

Also installed: `stow`, `fzf`, `ripgrep`, `eza`, `gh`, `lazygit`. Package lists live in [install/packages/](install/packages/) (Brewfile / apt-packages.txt / dnf-packages.txt / winget-packages.json).

## OS defaults (opt-in)

Curated productivity settings — key repeat, file-extension visibility, screenshot folder, dark mode on Windows, smart-quote suppression for code typing, etc. Never applied automatically.

```bash
./bootstrap.sh --apply-defaults      # macOS — 23 settings
```

```powershell
.\bootstrap.ps1 -ApplyDefaults       # Windows — 17 settings
```

Every apply writes a snapshot to `~/.dotfiles-defaults-backup/<timestamp>.json` capturing each key's previous value. Roll back with `dot defaults revert <snapshot>`.

CI never applies these (`--non-interactive` skips the block). Linux is intentionally out of scope — GNOME/KDE/XFCE differ too much for a single bundle.

## Forking

Personal info lives in three gitignored sidecars, seeded by `install/seed-identity.*`:

- `~/.gitconfig.local` — `[user]` name and email
- `~/.zshrc.local` — zsh tweaks, machine-specific exports
- `~/.pwsh.local.ps1` — pwsh equivalent

The repo itself has no personal info. Fork freely; bootstrap will prompt you for yours.

**Fork-safety guard.** To keep that promise mechanically, bootstrap enables a
pre-commit hook (`core.hooksPath=.githooks`) that runs `dot fork-check --staged`
on every commit. It fails the commit if a staged file contains your git email
(read from `~/.gitconfig.local`) or a credential shape — private key, GitHub or
Slack token, AWS key, or a real-looking email (`example.*` / `*.invalid`
placeholders are allowed). It's self-contained (no external scanner) and runs in
CI on every PR. Run it by hand anytime with `dot fork-check`; bypass a false
positive with `git commit --no-verify`. A git `user.name` is deliberately *not*
matched — handles legitimately appear in the repo's own URLs and LICENSE.

## Conflict handling

When a link's target spot is already occupied by a real file — or, on Windows, by a symlink this repo doesn't own — stowing never destroys anything:

- **Interactive runs** prompt per conflict: `[s]kip` (keep your file, link the rest of the module), `[b]ackup` (move it aside, then link), or `[A]ll` (backup this and every remaining conflict).
- **Non-interactive runs** (`--non-interactive` / `-NonInteractive`, or piped stdin) auto-backup every conflict, so CI and scripted installs always converge to repo state.
- Backups land in `~/.dotfiles-backup/<timestamp>/`, preserving paths relative to `$HOME`. Each run gets its own directory — nothing is ever overwritten. Restore by moving a file back.
- Repo content is never modified by stowing, and foreign symlinks are never silently replaced (backing one up moves the link itself; its destination is untouched).
- `dot stow --dry-run <module>` previews planned resolutions without touching anything.

## Notes

- **Uninstall:** `dot uninstall` removes only symlinks that resolve into this
  repo (real files and foreign symlinks are never touched, and a stray real file
  never aborts the run — unlike `stow -D`). It also removes the `dot` shim.
  Pre-install backups under `~/.dotfiles-backup/` are left in place and never
  auto-restored; the newest one's path is printed so you can restore by hand.
  Preview with `dot uninstall --dry-run`.
- **Doctor output:** required rows must pass; optional rows (`nvim`, `kitty`, CLI cluster, OS defaults) are informational and never fail the run.
- **kitty:** installed and stowed by default on macOS/Linux. It has no native Windows build (and WSL GUI is out of scope), so it's skipped there. The Nerd Font it uses is auto-installed; pick a theme with `kitty +kitten themes`.
- **Graphviz `dot` collision:** Graphviz installs a `dot` binary that this entrypoint shadows on PATH. If you use Graphviz, rename `bin/dot` (and the symlink it creates) or invoke Graphviz's `dot` via its full path.
- **CI:** `bootstrap.sh --non-interactive` / `bootstrap.ps1 -NonInteractive` run end-to-end on `ubuntu-latest`, `macos-latest`, and `windows-latest` per PR and weekly via cron — catches upstream package drift early.

## License

[MIT](LICENSE).
