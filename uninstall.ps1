# uninstall.ps1 - PowerShellBox (custom edition)
# Restores any backups made by setup.ps1 and removes the installed copies.
# Packages (starship, fastfetch, fzf, ...) are left in place.

$ErrorActionPreference = 'Stop'
$script:INSTALL_DIR = Join-Path $HOME ".local/share/powershellbox"
$script:NERD_FONTS = @("JetBrainsMono","FiraCode","CascadiaCode","Hack")
$script:BACKUP_SUFFIX = ".powershellbox-backup"

function Restore-File([string]$dest) {
    if (Test-Path $dest -PathType Link) { Remove-Item $dest -Force }
    $backup = "$dest$script:BACKUP_SUFFIX"
    if (Test-Path $backup) {
        Move-Item -Path $backup -Destination $dest -Force
        Write-Host "Restored $dest" -ForegroundColor Cyan
    }
}

Restore-File (Join-Path $HOME "Documents/PowerShell/Microsoft.PowerShell_profile.ps1")
Restore-File (Join-Path $HOME ".config/starship.toml")
Restore-File (Join-Path $HOME ".config/fastfetch/config.jsonc")

Remove-Item $script:INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue

foreach ($font in $script:NERD_FONTS) {
    Remove-Item (Join-Path $HOME ".local/share/fonts/${font}NF") -Recurse -Force -ErrorAction SilentlyContinue
}
if (Get-Command fc-cache -ErrorAction SilentlyContinue) { & fc-cache -f | Out-Null }

Write-Host "Uninstalled. Installed packages (starship, fastfetch, fzf, ...) were left in place." -ForegroundColor Cyan
Write-Host "Open a new PowerShell to apply the change." -ForegroundColor Cyan
