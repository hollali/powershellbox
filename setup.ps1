# setup.ps1 - PowerShellBox (custom edition)
# One-command PowerShell profile installer for Windows/Linux/macOS.
# Detects the package manager, installs deps, Starship, Fastfetch, Nerd Fonts,
# then symlinks the configs into place. Backs up existing files first.
#
# Run:        pwsh -ExecutionPolicy Bypass -File ./setup.ps1
# Preview:    pwsh -File ./setup.ps1 -DryRun
# Config only: pwsh -File ./setup.ps1 -NoInstall
# Reinstall:   pwsh -File ./setup.ps1 -Force

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoInstall,
    [switch]$Force,
    [string]$InstallDir = (Join-Path $HOME ".local/share/powershellbox")
)

$ErrorActionPreference = 'Stop'
$script:REPO_DIR = (Get-Item (Split-Path -Parent $PSCommandPath)).FullName
$script:INSTALL_DIR = $InstallDir
$script:NERD_FONTS = @("JetBrainsMono","FiraCode","CascadiaCode","Hack")
$script:BACKUP_SUFFIX = ".powershellbox-backup"
$script:IsWin = ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) -or $IsWindows
$script:VERSION = (Get-Content (Join-Path $script:REPO_DIR "VERSION") -Raw).Trim()

function Info([string]$msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Warn([string]$msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Invoke-Action([string]$msg, [scriptblock]$action) {
    if ($DryRun) { Write-Host "[dry-run] $msg" -ForegroundColor DarkGray; return $true }
    Info $msg
    try { & $action; return $true }
    catch { Warn "$msg failed: $_"; return $false }
}

# --- Detect package manager ---
$script:PM = "unknown"
foreach ($candidate in @("winget","choco","scoop","apt","dnf","pacman","zypper","brew")) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) { $script:PM = $candidate; break }
}
if ($script:PM -eq "unknown") {
    Warn "No supported package manager found."
    if (-not $DryRun) { exit 1 }
}

# Allow running as root (e.g. inside a test container). Keep every argument.
function sudo {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandAndArgs)
    if (-not $CommandAndArgs -or $CommandAndArgs.Count -eq 0) { return }
    $command = $CommandAndArgs[0]
    $rest = if ($CommandAndArgs.Count -gt 1) { $CommandAndArgs[1..($CommandAndArgs.Count-1)] } else { @() }
    & $command @rest
}

function Install-Pkg([string[]]$pkgs) {
    if ($DryRun) { return $true }
    switch ($script:PM) {
        "winget"   { & winget install --id $pkgs[0] --source winget --accept-package-agreements --accept-source-agreements -h; return }
        "choco"    { & choco install -y $pkgs; return }
        "scoop"    { & scoop install $pkgs; return }
        "apt"      { & sudo apt-get install -y $pkgs; return }
        "dnf"      { & sudo dnf install -y $pkgs; return }
        "pacman"   { & sudo pacman -S --needed --noconfirm $pkgs; return }
        "zypper"   { & sudo zypper --non-interactive install $pkgs; return }
        "brew"     { & brew install $pkgs; return }
    }
}

if (-not $NoInstall) {
    # --- 1. Dependencies ---
    Info "Installing dependencies..."
    if ($script:PM -eq "apt" -and -not $DryRun) { Invoke-Action "Updating apt index" { & sudo apt-get update } | Out-Null }
    $deps = @("git","curl","unzip","rsync","neovim","fzf","zoxide","eza","trash-cli","psmisc")
    foreach ($pkg in $deps) {
        if (Get-Command $pkg -ErrorAction SilentlyContinue) {
            if ($DryRun) { Write-Host "[dry-run] $pkg already installed" -ForegroundColor DarkGray }
            continue
        }
        Invoke-Action "Installing $pkg" { Install-Pkg @($pkg) } | Out-Null
    }

    # --- 2. Fastfetch ---
    function Install-Fastfetch() {
        if (Get-Command fastfetch -ErrorAction SilentlyContinue) { return $true }
        if ($DryRun) { Write-Host "[dry-run] Install fastfetch" -ForegroundColor DarkGray; return $true }
        Info "Installing fastfetch..."
        try { Install-Pkg @("fastfetch"); return $true } catch {}
        if ($script:PM -eq "apt") {
            & sudo apt-get install -y software-properties-common
            & sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
            & sudo apt-get update
            try { Install-Pkg @("fastfetch"); return $true } catch {}
        }
        return $false
    }
    if (-not (Install-Fastfetch)) { Warn "Install fastfetch manually: https://github.com/fastfetch-cli/fastfetch/releases" }

    # --- 3. Starship ---
    if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
        Invoke-Action "Installing Starship" { Install-Pkg @("starship") } | Out-Null
    }

    # --- 4. Nerd Fonts ---
    function Install-Font([string]$font) {
        $font_dir = Join-Path $HOME ".local/share/fonts/${font}NF"
        if ((Test-Path $font_dir -PathType Container) -and -not $Force) { return $true }
        try {
            Invoke-Action "Installing ${font} Nerd Font" {
                New-Item -ItemType Directory -Path $font_dir -Force | Out-Null
                $zip = Join-Path ([System.IO.Path]::GetTempPath()) "${font}.zip"
                Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip" -OutFile $zip -UseBasicParsing
                Expand-Archive -Path $zip -DestinationPath $font_dir -Force
                Remove-Item $zip -Force -ErrorAction SilentlyContinue
            } | Out-Null
            return $true
        } catch {
            Warn "Could not download ${font} Nerd Font (skipping)"
            return $false
        }
    }
    foreach ($font in $script:NERD_FONTS) { Install-Font $font | Out-Null }
    if (Get-Command fc-cache -ErrorAction SilentlyContinue) { Invoke-Action "Refreshing font cache" { & fc-cache -f } | Out-Null }
    if ($script:IsWin) {
        Warn "On Windows, also install a Nerd Font via the font settings GUI for prompt icons to render."
    }
} else {
    Info "Skipping package and font installation (-NoInstall)."
}

# --- 5. Copy config into place ---
$copyAction = {
    New-Item -ItemType Directory -Path (Join-Path $script:INSTALL_DIR "fastfetch") -Force | Out-Null
    foreach ($file in @("Microsoft.PowerShell_profile.ps1","starship.toml","completions.ps1","VERSION")) {
        Copy-Item -Path (Join-Path $script:REPO_DIR $file) -Destination $script:INSTALL_DIR -Force
    }
    Copy-Item -Path (Join-Path $script:REPO_DIR "fastfetch/config.jsonc") -Destination (Join-Path $script:INSTALL_DIR "fastfetch/config.jsonc") -Force
    if (Test-Path (Join-Path $script:REPO_DIR "plugins") -PathType Container) {
        Copy-Item -Path (Join-Path $script:REPO_DIR "plugins") -Destination $script:INSTALL_DIR -Recurse -Force
    }
    $meta = [ordered]@{
        Version     = $script:VERSION
        InstalledAt = (Get-Date).ToUniversalTime().ToString("o")
        SourceRepo  = $script:REPO_DIR
        PackageManager = $script:PM
        Fonts       = $script:NERD_FONTS
        InstallDir  = $script:INSTALL_DIR
    }
    $meta | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $script:INSTALL_DIR "install.json") -Encoding UTF8
}
Invoke-Action "Copying config to $script:INSTALL_DIR" $copyAction | Out-Null

# --- 6. Symlink (back up anything that already exists) ---
$profileDest = if ($script:IsWin) {
    Join-Path $HOME "Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
} else {
    Join-Path $HOME ".config/powershell/Microsoft.PowerShell_profile.ps1"
}

function Link-Config([string]$src, [string]$dest) {
    if ($DryRun) { Write-Host "[dry-run] Link $dest -> $src" -ForegroundColor DarkGray; return }
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir -PathType Container)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    $existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    if ($existing) {
        $isLink = ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($isLink) {
            $prev = $existing.Target
            if ($prev -ne $src) { Warn "Replacing existing symlink $dest -> $prev (target not backed up)" }
            Remove-Item -LiteralPath $dest -Force
        } elseif ($existing.PSIsContainer) {
            Warn "$dest is a directory; cannot link config there"
            return
        } else {
            $backup = "$dest${script:BACKUP_SUFFIX}"
            if (Test-Path $backup) { $backup = "$dest${script:BACKUP_SUFFIX}.$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
            Move-Item -LiteralPath $dest -Destination $backup -Force
            Info "Backed up $dest -> $backup"
        }
    }
    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src -ErrorAction Stop | Out-Null
    } catch {
        Warn "Symlink unavailable for $dest; copying the file instead. Enable Developer Mode or run as admin for true symlinks."
        Copy-Item -Path $src -Destination $dest -Force
        $marker = Join-Path $script:INSTALL_DIR ".fallback-links"
        $fallbacks = @()
        if (Test-Path $marker -PathType Leaf) { $fallbacks = @(Get-Content $marker) }
        if ($fallbacks -notcontains $dest) { $fallbacks += $dest }
        $fallbacks | Set-Content -Path $marker -Encoding UTF8
    }
}

Invoke-Action "Linking PowerShell profile" { Link-Config (Join-Path $script:INSTALL_DIR "Microsoft.PowerShell_profile.ps1") $profileDest } | Out-Null
Invoke-Action "Linking Starship config" { Link-Config (Join-Path $script:INSTALL_DIR "starship.toml") (Join-Path $HOME ".config/starship.toml") } | Out-Null
Invoke-Action "Linking Fastfetch config" { Link-Config (Join-Path $script:INSTALL_DIR "fastfetch/config.jsonc") (Join-Path $HOME ".config/fastfetch/config.jsonc") } | Out-Null

Info "Done! Set your terminal font to one of the installed 'Nerd Font' variants (e.g. 'JetBrainsMono Nerd Font'), then open a new PowerShell."
