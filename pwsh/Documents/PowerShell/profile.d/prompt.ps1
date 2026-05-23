# oh-my-posh prompt, themed via vendored JSON.
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $theme = Join-Path (Split-Path -Parent $PROFILE) 'themes' 'dotfiles.omp.json'
    if (Test-Path $theme) {
        oh-my-posh init pwsh --config $theme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}
