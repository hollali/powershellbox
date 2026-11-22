# Microsoft.PowerShell_profile.ps1 - PowerShellBox (custom edition)
# Tuned PowerShell profile: history handling, git aliases, smarter ls/ll/tree via eza,
# helpers like port, serve, gclone, gitroot, path, killport, myip, weather, extract,
# mkcd, backup, update, plus Starship, Fastfetch, zoxide/fzf integration, module
# toggles, plugins, argument completions and toolbox management commands.
#
# Symlinked to the PowerShell profile location by setup.ps1

# Set POWERSHELLBOX_ALLOW_NONINTERACTIVE=1 to load the helpers from scripts.
if (-not [Environment]::UserInteractive -and -not $env:POWERSHELLBOX_ALLOW_NONINTERACTIVE) { return }

# ---------- Version & configuration ----------
$script:PowerShellBoxVersion = '1.1.0'
$script:PowerShellBoxHome = Join-Path $HOME ".local/share/powershellbox"
$script:PowerShellBoxConfigPath = Join-Path $HOME ".config/powershellbox/config.ps1"
$script:PowerShellBoxConfig = @{}

if (Test-Path $script:PowerShellBoxConfigPath -PathType Leaf) {
    try {
        $loadedConfig = & $script:PowerShellBoxConfigPath
        if ($loadedConfig -is [System.Collections.IDictionary]) {
            $script:PowerShellBoxConfig = $loadedConfig
        } else {
            Write-Warning "PowerShellBox config did not return a hashtable: $($script:PowerShellBoxConfigPath)"
        }
    } catch {
        Write-Warning "Could not load PowerShellBox config ($($script:PowerShellBoxConfigPath)): $_"
    }
}

function PsbEnabled([string]$name) {
    $disabled = @()
    if ($script:PowerShellBoxConfig.ContainsKey('Disabled')) {
        $disabled += @($script:PowerShellBoxConfig.Disabled)
    }
    if ($env:POWERSHELLBOX_DISABLE) {
        $disabled += @($env:POWERSHELLBOX_DISABLE -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    if ($disabled -contains '*' -or $disabled -contains $name) { return $false }
    return $true
}

function PsbProfilePath() {
    if ($IsWindows -or [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        return (Join-Path $HOME "Documents/PowerShell/Microsoft.PowerShell_profile.ps1")
    }
    return (Join-Path $HOME ".config/powershell/Microsoft.PowerShell_profile.ps1")
}

# ---------- History ----------
$MaximumHistoryCount = 32767
$historyPath = Join-Path $HOME ".local/state/powershellbox"
if (-not (Test-Path $historyPath)) { New-Item -ItemType Directory -Path $historyPath -Force | Out-Null }
Set-PSReadLineOption -HistorySavePath (Join-Path $historyPath "history.txt") -MaximumHistoryCount 32767 -ErrorAction SilentlyContinue

# ---------- Environment ----------
$pathSeparator = [System.IO.Path]::PathSeparator
$localBin = Join-Path $HOME ".local/bin"
if (($env:PATH -split [regex]::Escape($pathSeparator)) -notcontains $localBin) {
    $env:PATH = "$localBin$pathSeparator$env:PATH"
}
if (Get-Command nvim -ErrorAction SilentlyContinue) { $env:EDITOR = "nvim"; $env:VISUAL = "nvim" }

# ---------- Aliases (simple command mappings only) ----------
if (PsbEnabled 'aliases') {
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
}

# ---------- Filesystem helpers ----------
if (PsbEnabled 'fs') {
    function ll {
        param([string[]]$Path = @("."))
        if (Get-Command eza -ErrorAction SilentlyContinue) {
            & eza -lAh --git --group-directories-first @Path
        } else {
            Get-ChildItem @Path -Force | Format-Table Mode, Length, LastWriteTime, Name -AutoSize
        }
    }
    function la {
        param([string[]]$Path = @("."))
        if (Get-Command eza -ErrorAction SilentlyContinue) {
            & eza -A --group-directories-first @Path
        } else {
            Get-ChildItem @Path -Force | Format-Table Mode, Length, Name -AutoSize
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
    function path {
        $env:PATH -split [regex]::Escape([System.IO.Path]::PathSeparator) | ForEach-Object { $_ }
    }
    function extract([string]$file) {
        if (-not $file) { Write-Host "Usage: extract <file>" -ForegroundColor Yellow; return }
        if (-not (Test-Path $file -PathType Leaf)) { Write-Host "'$file' is not a file" -ForegroundColor Yellow; return }
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
    function mkcd([string]$folder) {
        if (-not $folder) { Write-Host "Usage: mkcd <directory>" -ForegroundColor Yellow; return }
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Set-Location $folder
    }
    function backup([string]$item) {
        if (-not $item -or -not (Test-Path $item)) { Write-Host "Usage: backup <existing-path>" -ForegroundColor Yellow; return }
        $stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
        Copy-Item -Path $item -Destination ("$item.bak.$stamp") -Recurse -Force
    }
}

# ---------- Git helpers ----------
if (PsbEnabled 'git') {
    function gs { git status }
    function ga { param([string[]]$paths) git add $paths }
    function gaa { git add -A }
    function gc { param([string]$msg) git commit -m $msg }
    function gp { git push }
    function gl { git log --oneline --graph --decorate -n 15 }
    function gd { git diff }
    function gco { param([string]$branch) git checkout $branch }
    function gb { git branch }
    function gclone([string]$url) {
        if (-not $url) { Write-Host "Usage: gclone <repo-url>" -ForegroundColor Yellow; return }
        & git clone $url
        if ($LASTEXITCODE -ne 0) { return }
        $dir = [System.IO.Path]::GetFileNameWithoutExtension($url.TrimEnd('/'))
        if (Test-Path $dir -PathType Container) { Set-Location $dir }
    }
    function gitroot() {
        $root = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $root) { $root }
        else { Write-Host "Not inside a git repository" }
    }
}

# ---------- Network helpers ----------
if (PsbEnabled 'net') {
    function Get-PsbListeningConnections([int]$number = 0) {
        if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
            $params = @{ State = 'Listen'; ErrorAction = 'SilentlyContinue' }
            if ($number -gt 0) { $params.LocalPort = $number }
            return @(Get-NetTCPConnection @params | Select-Object LocalAddress, LocalPort, OwningProcess)
        }
        $tool = $null
        foreach ($candidate in @('ss','lsof','netstat')) {
            if (Get-Command $candidate -ErrorAction SilentlyContinue) { $tool = $candidate; break }
        }
        if (-not $tool) { return @() }
        $lines = switch ($tool) {
            'ss' {
                $toolArgs = if ($number -gt 0) { @('-ltnp', "( sport = :$number )") } else { @('-ltnp') }
                @(& ss @toolArgs 2>$null)
            }
            'netstat' { @(& netstat -ltnp 2>$null) }
            'lsof' {
                $toolArgs = if ($number -gt 0) { @('-nP', "-iTCP:$number", '-sTCP:LISTEN') } else { @('-nP', '-iTCP', '-sTCP:LISTEN') }
                @(& lsof @toolArgs 2>$null)
            }
        }
        $results = @()
        foreach ($line in $lines) {
            if ($tool -eq 'lsof') {
                if ($line -match '^(\S+)\s+(\d+)\s+.*?:(\d+)\s+\(LISTEN\)') {
                    $results += [pscustomobject]@{ LocalAddress = '*'; LocalPort = [int]$Matches[3]; OwningProcess = [int]$Matches[2] }
                }
            } elseif ($line -match 'LISTEN') {
                $address = $null
                $foundPort = 0
                if ($line -match '(\S+):(\d+)\s') {
                    $address = $Matches[1]
                    $foundPort = [int]$Matches[2]
                }
                if ($foundPort -gt 0 -and ($number -eq 0 -or $foundPort -eq $number)) {
                    $processId = if ($line -match 'pid=(\d+)') { [int]$Matches[1] } else { $null }
                    $results += [pscustomobject]@{ LocalAddress = $address; LocalPort = $foundPort; OwningProcess = $processId }
                }
            }
        }
        return $results
    }

    function Get-PsbLocalAddress() {
        if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
            $address = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.IPAddress -notlike '127.*' } |
                Select-Object -First 1 -ExpandProperty IPAddress
            if ($address) { return $address }
        }
        if (Get-Command hostname -ErrorAction SilentlyContinue) {
            $fromHostname = (& hostname -I 2>$null) -split '\s+' | Where-Object { $_ -match '^\d+\.' } | Select-Object -First 1
            if ($fromHostname) { return $fromHostname }
        }
        return "unavailable"
    }

    function myip {
        $local = Get-PsbLocalAddress
        try { $public = Invoke-RestMethod -Uri "https://ifconfig.me" -TimeoutSec 5 } catch { $public = "unavailable" }
        Write-Host "Local:  $local"
        Write-Host "Public: $public"
    }
    function weather([string]$city) {
        Invoke-RestMethod -Uri "https://wttr.in/$city?format=3" -ErrorAction SilentlyContinue
    }
    function ports {
        Get-PsbListeningConnections
    }
    function port([int]$number) {
        $conn = @(Get-PsbListeningConnections $number)
        if ($conn.Count -gt 0) { $conn }
        else { Write-Host "Nothing is listening on port $number" }
    }
    function killport([int]$number) {
        $conn = @(Get-PsbListeningConnections $number)
        if ($conn.Count -eq 0) { Write-Host "Nothing is listening on port $number"; return }
        $conn | Select-Object -ExpandProperty OwningProcess -Unique |
            Where-Object { $_ } | ForEach-Object { Stop-Process -Id $_ -Force }
    }
    function serve([int]$number = 8000) {
        if (Get-Command python3 -ErrorAction SilentlyContinue) {
            & python3 -m http.server $number
        } elseif (Get-Command python -ErrorAction SilentlyContinue) {
            & python -m http.server $number
        } else {
            Write-Host "Python is required for serve()" -ForegroundColor Yellow
        }
    }
}

# ---------- Package updates ----------
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

# ---------- Toolbox management ----------
if (PsbEnabled 'info') {
    function tbversion { $script:PowerShellBoxVersion }

    function tbmodules {
        @('aliases','fs','git','net','info','tools','fetch','plugins','completions') |
            ForEach-Object { [pscustomobject]@{ Module = $_; Enabled = (PsbEnabled $_) } }
    }

    function tbstatus {
        $profile = PsbProfilePath
        $checks = @(
            [pscustomobject]@{ Component = "Version"; Status = (tbversion); Detail = $script:PowerShellBoxHome },
            [pscustomobject]@{ Component = "Profile"; Status = $(if (Test-Path $profile -PathType Leaf) { "ok" } else { "missing" }); Detail = $profile }
            [pscustomobject]@{ Component = "Starship config"; Status = $(if (Test-Path (Join-Path $HOME ".config/starship.toml") -PathType Leaf) { "ok" } else { "missing" }); Detail = "~/.config/starship.toml" }
            [pscustomobject]@{ Component = "Fastfetch config"; Status = $(if (Test-Path (Join-Path $HOME ".config/fastfetch/config.jsonc") -PathType Leaf) { "ok" } else { "missing" }); Detail = "~/.config/fastfetch/config.jsonc" }
            [pscustomobject]@{ Component = "Completions"; Status = $(if (Test-Path (Join-Path $script:PowerShellBoxHome "completions.ps1") -PathType Leaf) { "ok" } else { "missing" }); Detail = "completions.ps1" }
            [pscustomobject]@{ Component = "Install metadata"; Status = $(if (Test-Path (Join-Path $script:PowerShellBoxHome "install.json") -PathType Leaf) { "ok" } else { "missing" }); Detail = "install.json" }
        )
        foreach ($tool in @('git','eza','starship','fastfetch','fzf','zoxide','nvim','trash-put')) {
            $cmd = Get-Command $tool -ErrorAction SilentlyContinue
            $checks += [pscustomobject]@{ Component = $tool; Status = $(if ($cmd) { "ok" } else { "missing" }); Detail = $(if ($cmd) { $cmd.Source } else { "not installed" }) }
        }
        $fontCount = @(Get-ChildItem (Join-Path $HOME ".local/share/fonts") -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*NF' }).Count
        $checks += [pscustomobject]@{ Component = "Nerd fonts"; Status = $fontCount; Detail = "~/.local/share/fonts/*NF" }
        $checks += [pscustomobject]@{ Component = "Disabled modules"; Status = (@(tbmodules | Where-Object { -not $_.Enabled } | ForEach-Object { $_.Module }) -join ', ') -replace '^$','none'; Detail = "config.ps1 / POWERSHELLBOX_DISABLE" }
        $checks
    }

    function tbupdate {
        param([switch]$Force)
        $metaPath = Join-Path $script:PowerShellBoxHome "install.json"
        if (-not (Test-Path $metaPath -PathType Leaf)) {
            Write-Host "No install metadata found; run setup.ps1 first." -ForegroundColor Yellow
            return
        }
        try { $meta = Get-Content $metaPath -Raw | ConvertFrom-Json } catch {
            Write-Host "Could not read install metadata: $_" -ForegroundColor Yellow
            return
        }
        $repo = $meta.SourceRepo
        if (-not $repo -or -not (Test-Path (Join-Path $repo ".git"))) {
            Write-Host "Source repository is not available: $repo" -ForegroundColor Yellow
            return
        }
        Write-Host "Updating PowerShellBox from $repo" -ForegroundColor Cyan
        & git -C $repo pull --ff-only
        if ($LASTEXITCODE -ne 0) { Write-Host "Git pull failed; not re-running setup." -ForegroundColor Yellow; return }
        $setup = Join-Path $repo "setup.ps1"
        if ($Force) { & $setup } else { & $setup -NoInstall }
    }

    function tbcompletion {
        param([string]$Path)
        $source = Join-Path $script:PowerShellBoxHome "completions.ps1"
        if (-not (Test-Path $source -PathType Leaf)) {
            Write-Host "Completions are not installed; run setup.ps1 first." -ForegroundColor Yellow
            return
        }
        if ($Path) {
            Copy-Item -Path $source -Destination $Path -Force
            Write-Host "Wrote argument completions to $Path" -ForegroundColor Cyan
        } else {
            Get-Content $source -Raw
        }
    }
}

# ---------- Tools ----------
if (PsbEnabled 'tools') {
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        & zoxide init powershell | Invoke-Expression
    }
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        & fzf --powershell | Invoke-Expression
    }
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        & starship init powershell | Invoke-Expression
    }
}

# ---------- Argument completions ----------
if (PsbEnabled 'completions') {
    $completions = Join-Path $script:PowerShellBoxHome "completions.ps1"
    if (Test-Path $completions -PathType Leaf) {
        try { . $completions } catch { Write-Warning "Could not load PowerShellBox completions: $_" }
    }
}

# ---------- Fastfetch banner ----------
# Turn it off with: $env:POWERSHELLBOX_NO_FETCH = 1, or disable the 'fetch' module.
if (PsbEnabled 'fetch' -and (Get-Command fastfetch -ErrorAction SilentlyContinue) -and -not $env:POWERSHELLBOX_NO_FETCH -and $host.Name -ne "Visual Studio Code Host") {
    fastfetch
}

# ---------- User plugins ----------
# Drop .ps1 files in ~/.config/powershellbox/plugins/ or list paths in config.ps1.
if (PsbEnabled 'plugins') {
    $pluginPaths = @()
    if ($script:PowerShellBoxConfig.ContainsKey('Plugins')) {
        $pluginPaths += @($script:PowerShellBoxConfig.Plugins)
    }
    foreach ($pluginDir in @((Join-Path $HOME ".config/powershellbox/plugins"), (Join-Path $script:PowerShellBoxHome "plugins"))) {
        if (Test-Path $pluginDir -PathType Container) {
            $pluginPaths += @(Get-ChildItem -Path $pluginDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.FullName })
        }
    }
    foreach ($pluginFile in ($pluginPaths | Select-Object -Unique)) {
        if (Test-Path $pluginFile -PathType Leaf) {
            try { . $pluginFile } catch { Write-Warning "PowerShellBox plugin failed ($pluginFile): $_" }
        } else {
            Write-Warning "PowerShellBox plugin not found: $pluginFile"
        }
    }
}
