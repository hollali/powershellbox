# setup.ps1 - PowerShellBox (custom edition)
# One-command PowerShell profile installer for Windows/Linux/macOS.
# Detects the package manager, installs deps, Starship, Fastfetch, Nerd Fonts,
# then symlinks the configs into place. Backs up existing files first.
#
# Run: pwsh -ExecutionPolicy Bypass -File ./setup.ps1

$ErrorActionPreference = 'Stop'
$script:REPO_DIR = (Get-Item (Split-Path -Parent $PSCommandPath)).FullName
$script:INSTALL_DIR = Join-Path $HOME ".local/share/powershellbox"
$script:NERD_FONTS = @("JetBrainsMono","FiraCode","CascadiaCode","Hack")
$script:BACKUP_SUFFIX = ".powershellbox-backup"
$script:IsWindows = ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) -or $IsWindows

function Info([string]$msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Warn([string]$msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }

# --- Detect package manager ---
$script:PM = "unknown"
foreach ($pm in @("winget","choco","scoop","apt","dnf","pacman","zypper","brew")) {
    if (Get-Command $pm -ErrorAction SilentlyContinue) { $script:PM = $pm; break }
}
if ($script:PM -eq "unknown") { Warn "No supported package manager found."; exit 1 }

function Install-Pkg([string[]]$pkgs) {
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

# Allow running as root (e.g. inside a test container)
try {
    if ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent().IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        function sudo { param($cmd) & $cmd }
    }
} catch { }

# --- 1. Dependencies ---
Info "Installing dependencies..."
if ($script:PM -eq "apt") { & sudo apt-get update }
$deps = @("git","curl","unzip","rsync","neovim","fzf","zoxide","trash-cli","psmisc")
foreach ($pkg in $deps) {
    try { Install-Pkg @($pkg) } catch { Warn "Could not install $pkg (skipping)" }
}

# --- 2. Fastfetch ---
function Install-Fastfetch() {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) { return $true }
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
    Info "Installing Starship..."
    try { Install-Pkg @("starship") } catch { Warn "Could not install Starship via package manager (install manually: https://starship.rs)" }
}

# --- 4. Nerd Fonts ---
function Install-Font([string]$font) {
    $font_dir = Join-Path $HOME ".local/share/fonts/${font}NF"
    if (Test-Path $font_dir) { return $true }
    Info "Installing ${font} Nerd Font..."
    try {
        New-Item -ItemType Directory -Path $font_dir -Force | Out-Null
        $zip = Join-Path $env:TEMP "${font}.zip"
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip" -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $font_dir -Force
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Warn "Could not download ${font} Nerd Font (skipping)"
        return $false
    }
}
foreach ($font in $script:NERD_FONTS) { Install-Font $font | Out-Null }
if (Get-Command fc-cache -ErrorAction SilentlyContinue) { & fc-cache -f | Out-Null }

# --- 5. Copy config into place ---
Info "Copying config to $script:INSTALL_DIR..."
New-Item -ItemType Directory -Path (Join-Path $script:INSTALL_DIR "fastfetch") -Force | Out-Null
Copy-Item -Path (Join-Path $script:REPO_DIR "Microsoft.PowerShell_profile.ps1") -Destination $script:INSTALL_DIR -Force
Copy-Item -Path (Join-Path $script:REPO_DIR "starship.toml") -Destination $script:INSTALL_DIR -Force
Copy-Item -Path (Join-Path $script:REPO_DIR "fastfetch/config.jsonc") -Destination (Join-Path $script:INSTALL_DIR "fastfetch") -Force

# --- 6. Symlink (back up anything that already exists) ---
if ($script:IsWindows) {
    $profileDest = Join-Path $HOME "Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
} else {
    $profileDest = Join-Path $HOME ".config/powershell/Microsoft.PowerShell_profile.ps1"
}

function Link-Config([string]$src, [string]$dest) {
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    if (Test-Path $dest -and -not (Test-Path $dest -PathType Container)) {
        if (-not (Test-Path $dest -PathType Link)) {
            Move-Item -Path $dest -Destination ("$dest$script:BACKUP_SUFFIX") -Force
            Info "Backed up $dest"
        }
    }
    if (Test-Path $dest -PathType Link) {
        $prev = (Get-Item $dest).Target
        if ($prev -ne $src) { Warn "Replacing existing symlink $dest -> $prev (target not backed up)" }
    }
    New-Item -ItemType SymbolicLink -Path $dest -Target $src -Force | Out-Null
}

Link-Config (Join-Path $script:INSTALL_DIR "Microsoft.PowerShell_profile.ps1") $profileDest
Link-Config (Join-Path $script:INSTALL_DIR "starship.toml") (Join-Path $HOME ".config/starship.toml")
Link-Config (Join-Path $script:INSTALL_DIR "fastfetch/config.jsonc") (Join-Path $HOME ".config/fastfetch/config.jsonc")

Info "Done! Set your terminal font to one of the installed 'Nerd Font' variants (e.g. 'JetBrainsMono Nerd Font'), then open a new PowerShell."
