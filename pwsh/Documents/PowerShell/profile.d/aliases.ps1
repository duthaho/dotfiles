# PowerShell-flavored equivalents of the zsh aliases.

# Navigation
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# Listing
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ll { eza -lah --group-directories-first @args }
} else {
    function ll { Get-ChildItem -Force @args }
}

# Editor
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias vim nvim
}

# Git shortcut
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias g lazygit
}

# Misc
Set-Alias which Get-Command
function gs { git status -sb @args }
function gp { git push @args }
function gl { git log --oneline --graph --decorate -20 @args }
