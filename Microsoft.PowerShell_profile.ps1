# Microsoft.PowerShell_profile.ps1 - PowerShellBox (custom edition)
# Tuned PowerShell profile: history handling, git aliases, smarter ls/ll/tree via eza,
# helpers like port, serve, gclone, gitroot, path, killport, myip, weather, extract,
# starship prompt, fastfetch banner, zoxide/fzf integration.
#
# Symlinked to the PowerShell profile location by setup.ps1

# Only run in interactive shells
if (-not [Environment]::UserInteractive) { return }

# ---------- History ----------
$MaximumHistoryCount = 50000
$historyPath = Join-Path $HOME ".local/state/powershellbox"
if (-not (Test-Path $historyPath)) { New-Item -ItemType Directory -Path $historyPath -Force | Out-Null }
Set-PSReadLineOption -HistorySavePath (Join-Path $historyPath "history.txt") -MaximumHistoryCount 50000 -ErrorAction SilentlyContinue

# ---------- Environment ----------
$env:PATH = "$HOME/.local/bin;" + $env:PATH
if (Get-Command nvim -ErrorAction SilentlyContinue) { $env:EDITOR = "nvim"; $env:VISUAL = "nvim" }

# ---------- Aliases (simple command mappings only) ----------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias ls eza -Force
} else {
    Set-Alias ls Get-ChildItem -Force
}
Set-Alias grep Select-String -Force
Set-Alias cp Copy-Item -Force
Set-Alias mv Move-Item -Force
Set-Alias c Clear-Host -Force
if (Get-Command trash-put -ErrorAction SilentlyContinue) { Set-Alias rm trash-put -Force }
if (Get-Command nvim -ErrorAction SilentlyContinue) { Set-Alias vim nvim -Force }

# ---------- Aliases / functions with arguments ----------
function ll {
    param([string[]]$Path = @("."))
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        & eza -lAh --git --group-directories-first @Path
    } else {
        Get-ChildItem @Path -Force | Format-List
    }
}
function la {
    param([string[]]$Path = @("."))
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        & eza -A --group-directories-first @Path
    } else {
        Get-ChildItem @Path -Force | Where-Object { $_.Name -notmatch '^\.' }
    }
}
function tree {
    param([int]$Level = 2, [string[]]$Path = @("."))
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        & eza --tree --level=$Level @Path
    } else {
        Get-ChildItem @Path -Recurse -Depth $Level -Force
    }
}
function df {
    Get-Volume | Select-Object DriveLabel, FileSystemType, DriveType,
        @{N="SizeGB";E={[math]::Round($_.Size/1GB,2)}},
        @{N="FreeGB";E={[math]::Round($_.FreeSpace/1GB,2)}}
}
function ports {
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, OwningProcess
}
function reload { & $PROFILE }
function bashrc { & $env:EDITOR $PROFILE }
function ff { fastfetch }
function gs { git status }
function ga { param([string[]]$paths) git add $paths }
function gaa { git add -A }
function gc { param([string]$msg) git commit -m $msg }
function gp { git push }
function gl { git log --oneline --graph --decorate -HeadCount 15 }
function gd { git diff }
function gco { param([string]$branch) git checkout $branch }
function gb { git branch }
function myip {
    $local = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.IPAddress -notlike '127.*' } | Select-Object -First 1).IPAddress
    try { $public = Invoke-RestMethod -Uri "https://ifconfig.me" -TimeoutSec 5 } catch { $public = "unavailable" }
    Write-Host "Local:  $local"
    Write-Host "Public: $public"
}
function weather([string]$city) {
    Invoke-RestMethod -Uri "https://wttr.in/$city?format=3" -ErrorAction SilentlyContinue
}
function port([int]$port) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) { $conn | Select-Object LocalAddress, LocalPort, OwningProcess }
    else { Write-Host "Nothing is listening on port $port" }
}
function serve([int]$port = 8000) {
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        & python3 -m http.server $port
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        & python -m SimpleHTTPServer $port
    } else {
        Write-Host "Python is required for serve()" -ForegroundColor Yellow
    }
}
function gclone([string]$url) {
    if (-not $url) { Write-Host "Usage: gclone <repo-url>" -ForegroundColor Yellow; return }
    & git clone $url
    $dir = ([System.IO.Path]::GetFileNameWithoutExtension($url))
    Set-Location $dir
}
function gitroot() {
    & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "Not inside a git repository" }
}
function path() { $env:PATH -split ';' | ForEach-Object { $_ } }
function extract([string]$file) {
    if (-not $file) { Write-Host "Usage: extract <file>" -ForegroundColor Yellow; return }
    if (-not (Test-Path $file)) { Write-Host "'$file' is not a file" -ForegroundColor Yellow; return }
    switch -regex ($file) {
        ".*\.(tar\.gz|tgz)$"    { tar xzf $file; break }
        ".*\.(tar\.bz2|tbz2)$"  { tar xjf $file; break }
        ".*\.(tar\.xz|txz)$"    { tar xJf $file; break }
        ".*\.tar$"              { tar xf $file; break }
        ".*\.zip$"              { Expand-Archive -Path $file -DestinationPath ([System.IO.Path]::GetFileNameWithoutExtension($file)) -Force; break }
        ".*\.gz$"               { gunzip $file; break }
        ".*\.xz$"               { unxz $file; break }
        default {
            if (Get-Command 7z -ErrorAction SilentlyContinue) { & 7z x $file }
            else { Write-Host "Cannot extract '$file'" -ForegroundColor Yellow }
        }
    }
}
function update() {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget upgrade --all --accept-source-agreements --accept-package-agreements -h
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        & choco upgrade all -y
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        & scoop update
        & scoop update *
    } elseif (Get-Command apt-get -ErrorAction SilentlyContinue) {
        & sudo env DEBIAN_FRONTEND=noninteractive apt-get update
        & sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
        & sudo dnf upgrade --refresh -y
    } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
        & sudo pacman -Syu --noconfirm
    } elseif (Get-Command zypper -ErrorAction SilentlyContinue) {
        & sudo zypper --non-interactive refresh
        & sudo zypper --non-interactive update
    } elseif (Get-Command brew -ErrorAction SilentlyContinue) {
        & brew update
        & brew upgrade
    } else {
        Write-Host "No supported package manager found" -ForegroundColor Yellow
    }
}
function mkcd([string]$path) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}
function backup([string]$path) {
    $stamp = Get-Date -Format "yyyy-MM-dd-HHmm"
    Copy-Item -Path $path -Destination ("$path.bak.$stamp") -Recurse -Force
}
function killport([int]$port) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) { Stop-Process -Id $conn.OwningProcess -Force }
    else { Write-Host "Nothing is listening on port $port" }
}

# ---------- Tools ----------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    & zoxide init powershell | Invoke-Expression
}

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    & fzf --powershell | Invoke-Expression
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    & starship init powershell | Invoke-Expression
}

# ---------- Fastfetch banner ----------
# Turn it off with: $env:POWERSHELLBOX_NO_FETCH = 1
if (Get-Command fastfetch -ErrorAction SilentlyContinue -and -not $env:POWERSHELLBOX_NO_FETCH -and $host.Name -ne "Visual Studio Code Host") {
    fastfetch
}
