# Pester tests for PowerShellBox.
# Run with: Invoke-Pester ./tests

Describe 'PowerShell script syntax' {
    BeforeDiscovery {
        $script:repoRootForDiscovery = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        $script:allScripts = @(Get-ChildItem -Path $script:repoRootForDiscovery -Filter '*.ps1' -Recurse -File |
            ForEach-Object { @{ script = $_.FullName } })
    }

    It 'parses <script> without errors' -TestCases $script:allScripts {
        param($script)
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Version metadata' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        $script:profilePath = Join-Path $script:repoRoot 'Microsoft.PowerShell_profile.ps1'
        $env:POWERSHELLBOX_ALLOW_NONINTERACTIVE = '1'
        $env:POWERSHELLBOX_DISABLE = 'fetch,tools,plugins'
        . $script:profilePath
    }

    AfterAll {
        Remove-Item Env:\POWERSHELLBOX_ALLOW_NONINTERACTIVE -ErrorAction SilentlyContinue
        Remove-Item Env:\POWERSHELLBOX_DISABLE -ErrorAction SilentlyContinue
    }

    It 'VERSION matches the profile constant' {
        $version = (Get-Content (Join-Path $script:repoRoot 'VERSION') -Raw).Trim()
        (Get-Content $script:profilePath -Raw) | Should -Match "\`$script:PowerShellBoxVersion = '$version'"
    }

    It 'tbversion returns the VERSION value' {
        tbversion | Should -Be ((Get-Content (Join-Path $script:repoRoot 'VERSION') -Raw).Trim())
    }
}

Describe 'Profile helpers' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        $env:POWERSHELLBOX_ALLOW_NONINTERACTIVE = '1'
        $env:POWERSHELLBOX_DISABLE = 'fetch,tools,plugins'
        . (Join-Path $script:repoRoot 'Microsoft.PowerShell_profile.ps1')
    }

    AfterAll {
        Remove-Item Env:\POWERSHELLBOX_ALLOW_NONINTERACTIVE -ErrorAction SilentlyContinue
        Remove-Item Env:\POWERSHELLBOX_DISABLE -ErrorAction SilentlyContinue
    }

    It 'path splits PATH on the platform separator' {
        $separator = [System.IO.Path]::PathSeparator
        $expected = @($env:PATH -split [regex]::Escape($separator))
        $actual = @(path)
        $actual.Count | Should -Be $expected.Count
    }

    It 'la includes hidden files without eza' {
        $temp = Join-Path ([System.IO.Path]::GetTempPath()) "psb-la-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $temp '.hidden-file') -Force | Out-Null
        try {
            $output = la $temp | Out-String
            $output | Should -Match 'hidden-file'
        } finally {
            Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'mkcd creates and enters a directory' {
        $parent = Join-Path ([System.IO.Path]::GetTempPath()) "psb-mkcd-$([guid]::NewGuid().ToString('N'))"
        $target = Join-Path $parent 'child'
        try {
            Push-Location
            mkcd $target
            (Get-Location).Path | Should -Be (Get-Item $target).FullName
        } finally {
            Pop-Location
            Remove-Item $parent -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'backup creates a timestamped copy' {
        $temp = Join-Path ([System.IO.Path]::GetTempPath()) "psb-backup-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        $file = Join-Path $temp 'note.txt'
        Set-Content -Path $file -Value 'payload'
        try {
            backup $file
            @(Get-ChildItem -Path $temp -Filter 'note.txt.bak.*' -File).Count | Should -Be 1
        } finally {
            Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'extract reports a missing file' {
        (extract (Join-Path ([System.IO.Path]::GetTempPath()) 'definitely-missing-psb.zip') 6>&1 | Out-String) |
            Should -Match 'not a file'
    }

    It 'killport reports when a port is free' {
        (killport 65534 6>&1 | Out-String) | Should -Match 'Nothing is listening'
    }

    It 'PsbEnabled honors the environment override' {
        $original = $env:POWERSHELLBOX_DISABLE
        try {
            $script:PowerShellBoxConfig = @{}
            $env:POWERSHELLBOX_DISABLE = 'git'
            PsbEnabled 'git' | Should -BeFalse
            PsbEnabled 'net' | Should -BeTrue
            $env:POWERSHELLBOX_DISABLE = '*'
            PsbEnabled 'anything' | Should -BeFalse
        } finally {
            $env:POWERSHELLBOX_DISABLE = $original
        }
    }

    It 'tbmodules lists all configurable modules' {
        @(tbmodules).Count | Should -Be 9
    }

    It 'tbstatus returns a component report' {
        $status = @(tbstatus)
        $status.Count | Should -BeGreaterThan 5
        $status.Component | Should -Contain 'Version'
    }
}

Describe 'setup.ps1' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        $script:setupPath = Join-Path $script:repoRoot 'setup.ps1'
        $script:uninstallPath = Join-Path $script:repoRoot 'uninstall.ps1'
        $script:pwshPath = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
        $script:originalHome = $env:HOME
        $script:dryHome = Join-Path ([System.IO.Path]::GetTempPath()) "psb-dry-$([guid]::NewGuid().ToString('N'))"
        $script:installHome = Join-Path ([System.IO.Path]::GetTempPath()) "psb-install-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:dryHome -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:installHome '.config/powershell') -Force | Out-Null
        Set-Content -Path (Join-Path $script:installHome '.config/powershell/Microsoft.PowerShell_profile.ps1') -Value 'ORIGINAL'
    }

    AfterAll {
        $env:HOME = $script:originalHome
        Remove-Item $script:dryHome -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $script:installHome -Recurse -Force -ErrorAction SilentlyContinue
    }

    It '-DryRun does not write any files' {
        try {
            $env:HOME = $script:dryHome
            $output = & $script:pwshPath -NoProfile -File $script:setupPath -DryRun 6>&1 | Out-String
            $found = @(Get-ChildItem -Path $script:dryHome -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
            "DIAG pwshPath=$($script:pwshPath) version=$($PSVersionTable.PSVersion) home=$($env:HOME)`nOUTPUT:$output`nFOUND:$($found -join ', ')" | Write-Host
            Test-Path (Join-Path $script:dryHome '.local') | Should -BeFalse
            Test-Path (Join-Path $script:dryHome '.config') | Should -BeFalse
        } finally {
            $env:HOME = $script:originalHome
        }
    }

    It '-NoInstall copies configs, links the profile and writes metadata' {
        try {
            $env:HOME = $script:installHome
            & $script:pwshPath -NoProfile -File $script:setupPath -NoInstall | Out-Null
            Test-Path (Join-Path $script:installHome '.local/share/powershellbox/Microsoft.PowerShell_profile.ps1') -PathType Leaf | Should -BeTrue
            Test-Path (Join-Path $script:installHome '.local/share/powershellbox/completions.ps1') -PathType Leaf | Should -BeTrue
            Test-Path (Join-Path $script:installHome '.local/share/powershellbox/install.json') -PathType Leaf | Should -BeTrue
            Test-Path (Join-Path $script:installHome '.config/powershell/Microsoft.PowerShell_profile.ps1') | Should -BeTrue
            Test-Path (Join-Path $script:installHome '.config/powershell/Microsoft.PowerShell_profile.ps1.powershellbox-backup') -PathType Leaf | Should -BeTrue
        } finally {
            $env:HOME = $script:originalHome
        }
    }

    It 'uninstall restores the original profile' {
        try {
            $env:HOME = $script:installHome
            & $script:pwshPath -NoProfile -File $script:uninstallPath | Out-Null
            (Get-Content (Join-Path $script:installHome '.config/powershell/Microsoft.PowerShell_profile.ps1') -Raw).Trim() |
                Should -Be 'ORIGINAL'
            Test-Path (Join-Path $script:installHome '.local/share/powershellbox') | Should -BeFalse
        } finally {
            $env:HOME = $script:originalHome
        }
    }
}
