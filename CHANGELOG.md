# Changelog

All notable changes to PowerShellBox are documented here.

## 1.1.0

- Fixed: `eza` is now installed by `setup.ps1` so `ls`/`ll`/`la`/`tree` use it when available.
- Fixed: `gl` uses `git log ... -n 15` instead of the invalid `-HeadCount` flag.
- Fixed: `path` and the `PATH` prepend now use `[IO.Path]::PathSeparator`, so they work on Windows, Linux and macOS.
- Fixed: `la` no longer hides dotfiles when `eza` is unavailable.
- Fixed: the root `sudo` shim no longer drops arguments after the command.
- Fixed: `$MaximumHistoryCount` is set to the supported maximum of 32767.
- Fixed: `setup.ps1`/`uninstall.ps1` detect symlinks via reparse points instead of the invalid `-PathType Link`.
- Fixed: `serve()` uses `python -m http.server` on both Python 2 and 3.
- Added: cross-portable network helpers — `port`, `ports`, `killport` and `myip` fall back to `ss`, `lsof` or `netstat` when `Get-NetTCPConnection`/`Get-NetIPAddress` are unavailable.
- Added: `setup.ps1 -DryRun`, `-NoInstall`, `-Force` and `-InstallDir` for previewing, config-only refreshes, reinstalling fonts and isolated installs.
- Added: unique, timestamped backups so re-running setup never overwrites an earlier backup.
- Added: symlink fallback to copied files on systems where symlinks are unavailable, with clean uninstall.
- Added: `install.json` metadata, `tbversion`, `tbstatus`, `tbmodules`, `tbupdate` and `tbcompletion`.
- Added: configurable module toggles via `~/.config/powershellbox/config.ps1` or `POWERSHELLBOX_DISABLE`.
- Added: plugin loading from `~/.config/powershellbox/plugins/` and `config.ps1`.
- Added: argument completions for git branches, listening ports and file paths.
- Added: Pester test suite and a GitHub Actions matrix across Linux, Windows and macOS.

## 1.0.0

- Initial port of bashbox to PowerShell: tuned profile, Starship, Fastfetch, Nerd Fonts, install and uninstall scripts.
