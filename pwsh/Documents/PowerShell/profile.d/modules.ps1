# PSReadLine — predictive intellisense, arrow-key history search.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# posh-git — branch info in prompt, completions
if (Get-Module -ListAvailable -Name posh-git) {
    Import-Module posh-git
}

# Terminal-Icons — file icons in Get-ChildItem
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}
