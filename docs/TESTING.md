# Testing the Bootstrap

v1 ships only after the bootstrap is verified once on each of the four supported platforms. No CI; manual recipes below.

## macOS

Use a fresh user account on the dev host:

1. `System Settings → Users & Groups → Add Account → Standard`.
2. Log in to that account.
3. Open Terminal:

   ```bash
   git clone <repo URL> ~/.dotfiles
   cd ~/.dotfiles && ./bootstrap.sh
   ./doctor.sh
   ```

4. All required rows should pass.

## Linux (Ubuntu 24.04 in Docker)

```bash
docker run --rm -it \
  -v "$(pwd):/dotfiles-src:ro" \
  ubuntu:24.04 bash -c '
    set -e
    apt-get update -y >/dev/null
    apt-get install -y sudo curl git >/dev/null
    cp -r /dotfiles-src /root/.dotfiles
    cd /root/.dotfiles
    echo "n" | ./bootstrap.sh
    ./doctor.sh
  '
```

Idempotency test: run the same script twice in succession inside the same container session.

## WSL2

On a Windows 11 host:

```powershell
wsl --install -d Ubuntu-24.04
# Create a fresh Ubuntu user when prompted, then:
wsl
```

Inside WSL:

```bash
git clone <repo URL> ~/.dotfiles
cd ~/.dotfiles && ./bootstrap.sh
./doctor.sh
```

## Windows-native (Windows Sandbox)

Sandbox is the throwaway VM that ships with Windows 11 Pro. Enable once at:
`Settings → Apps → Optional features → More Windows features → Windows Sandbox`.

1. Save the following as `sandbox.wsb` (adjust HostFolder path):

   ```xml
   <Configuration>
     <MappedFolders>
       <MappedFolder>
         <HostFolder>C:\full\path\to\dotfiles\repo</HostFolder>
         <SandboxFolder>C:\Users\WDAGUtilityAccount\dotfiles-src</SandboxFolder>
         <ReadOnly>true</ReadOnly>
       </MappedFolder>
     </MappedFolders>
   </Configuration>
   ```

2. Double-click `sandbox.wsb`. Sandbox boots.

3. Inside the Sandbox:
   - Enable Developer Mode (Settings → Privacy & Security → For developers).
   - Install PowerShell 7: `winget install Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements`.
   - Open PowerShell 7 (`pwsh`).
   - Run:

     ```powershell
     Copy-Item C:\Users\WDAGUtilityAccount\dotfiles-src `
       -Destination $HOME\.dotfiles -Recurse
     cd $HOME\.dotfiles
     .\bootstrap.ps1
     .\doctor.ps1
     ```

4. All required rows should pass.

5. Idempotency: re-run `bootstrap.ps1` and `doctor.ps1`. No errors expected.

## Acceptance criteria (recap from spec §11)

A platform passes verification when, in a fresh user environment:

1. `bootstrap` runs to completion after three identity prompts.
2. `doctor` reports all required rows passing.
3. New terminal session shows the expected prompt, aliases work, `git config --get user.email` returns the seeded value, and `tmux` launches (Unix only).
4. Running bootstrap a second time produces no errors and no duplicate symlinks.
5. `stow -D <module>` (Unix) or `symlink-windows.ps1 -Remove` (Windows) cleanly removes a module.
