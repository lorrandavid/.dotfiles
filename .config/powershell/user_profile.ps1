# Shell
# Invoke-Expression (&starship init powershell)
&starship init powershell --print-full-init | Out-String | Invoke-Expression

# PSReadLine
Import-Module PSReadLine
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Improve prediction/completion contrast for light terminal themes
try {
    Set-PSReadLineOption -Colors @{
        InlinePrediction       = [ConsoleColor]::DarkGray
        ListPrediction         = [ConsoleColor]::DarkGray
        ListPredictionSelected = [ConsoleColor]::Black
    }
} catch {
}

# Fzf
Import-Module PSFzf
Set-PSFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

# Alias
Set-Alias vim nvim
Set-Alias ll ls
Set-Alias g git
Set-Alias grep findstr

# Utilities
function which ($command)
{
    Get-Command -Name $command -ErrorAction SilentlyContinue
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# function ralph {
# 	& "$HOME\ai\ralph.ps1" @args
# }
