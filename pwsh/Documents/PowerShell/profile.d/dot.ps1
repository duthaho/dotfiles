if ($env:DOTFILES -and (Test-Path "$env:DOTFILES\bin\dot.ps1")) {
    function dot { & "$env:DOTFILES\bin\dot.ps1" @args }
}
