# uninstall.ps1 - PowerShellBox (custom edition)
# Restores any backups made by setup.ps1 and removes the installed copies.
# Packages (starship, fastfetch, fzf, ...) are left in place.
#
# Run: pwsh -ExecutionPolicy Bypass -File ./uninstall.ps1

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$InstallDir = (Join-Path $HOME ".local/share/powershellbox"),
    [string]$HomeDir = $HOME
)

$ErrorActionPreference = 'Stop'
$script:PsbHome = $HomeDir
$script:INSTALL_DIR = $InstallDir
$script:NERD_FONTS = @("JetBrainsMono","FiraCode","CascadiaCode","Hack")
$script:BACKUP_SUFFIX = ".powershellbox-backup"
$script:IsWin = ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) -or $IsWindows

function Restore-File([string]$dest) {
    if ($DryRun) { Write-Host "[dry-run] Restore $dest" -ForegroundColor DarkGray; return }
    $existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    if ($existing -and ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        Remove-Item -LiteralPath $dest -Force
    }
    $backups = @(Get-ChildItem -Path (Split-Path -Parent $dest) -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$(Split-Path -Leaf $dest)${script:BACKUP_SUFFIX}*" } |
        Sort-Object Name -Descending)
    if ($backups.Count -gt 0) {
        Move-Item -Path $backups[0].FullName -Destination $dest -Force
        Write-Host "Restored $dest from $($backups[0].Name)" -ForegroundColor Cyan
    } elseif (Test-Path $dest -PathType Leaf) {
        Write-Warning "Not removing ${dest}: it is a regular file with no PowerShellBox backup."
    }
}

$fallbackMarker = Join-Path $script:INSTALL_DIR ".fallback-links"
if (Test-Path $fallbackMarker -PathType Leaf) {
    foreach ($path in @(Get-Content $fallbackMarker)) {
        if ($path -and (Test-Path $path -PathType Leaf)) {
            if ($DryRun) { Write-Host "[dry-run] Remove copied config $path" -ForegroundColor DarkGray }
            else { Remove-Item $path -Force; Write-Host "Removed copied config $path" -ForegroundColor Cyan }
        }
    }
}

$profileDest = if ($script:IsWin) {
    Join-Path $script:PsbHome "Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
} else {
    Join-Path $script:PsbHome ".config/powershell/Microsoft.PowerShell_profile.ps1"
}

Restore-File $profileDest
Restore-File (Join-Path $script:PsbHome ".config/starship.toml")
Restore-File (Join-Path $script:PsbHome ".config/fastfetch/config.jsonc")

if ($DryRun) {
    Write-Host "[dry-run] Remove $($script:INSTALL_DIR)" -ForegroundColor DarkGray
} else {
    Remove-Item $script:INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($font in $script:NERD_FONTS) {
    $fontDir = Join-Path $script:PsbHome ".local/share/fonts/${font}NF"
    if (Test-Path $fontDir -PathType Container) {
        if ($DryRun) { Write-Host "[dry-run] Remove $fontDir" -ForegroundColor DarkGray }
        else { Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
if (Get-Command fc-cache -ErrorAction SilentlyContinue) {
    if (-not $DryRun) { & fc-cache -f | Out-Null }
}

Write-Host "Uninstalled. Installed packages (starship, fastfetch, fzf, ...) were left in place." -ForegroundColor Cyan
Write-Host "Open a new PowerShell to apply the change." -ForegroundColor Cyan
