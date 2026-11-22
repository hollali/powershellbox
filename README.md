# PowerShellBox (custom edition)

A one-command PowerShell profile plus a linutil-style toolbox for Windows/Linux/macOS:
a tuned `Microsoft.PowerShell_profile.ps1`, the Starship prompt with swappable palettes,
a Fastfetch system-info banner, one-key app installers, a doctor check, and Nerd Fonts
so prompt icons render.

Inspired by [hollali/bashbox](https://github.com/hollali/bashbox) (MIT), ported to PowerShell.

## What you get

- A tuned PowerShell profile with history handling, git aliases, smarter `ls`/`ll`/`la`/`tree` via eza when available, and helpers like `port`, `serve`, `gclone`, `gitroot`, `path`, `killport`, `myip`, `weather`, `extract`, `mkcd`, `backup`, and `update`
- Cross-platform networking: `port`, `ports`, `killport` and `myip` use `Get-NetTCPConnection`/`Get-NetIPAddress` when present and fall back to `ss`, `lsof` or `netstat`
- An `update()` helper that upgrades packages non-interactively across winget, choco, scoop, apt, dnf, pacman, zypper, and brew
- The Starship prompt with a Nord-style two-line layout (`starship.toml`); your username is always visible and the hostname appears over SSH
- Fastfetch as a system-info banner on every new shell, with its own config, an `ff` alias, and an opt-out switch (`$env:POWERSHELLBOX_NO_FETCH = 1`; it also stays off inside VS Code)
- Zoxide, fzf, and Neovim wired in when available
- Tab completions for git branches, listening ports, and file paths
- Configurable modules and user plugins
- Toolbox commands: `tbversion`, `tbstatus`, `tbmodules`, `tbupdate`, `tbcompletion`
- Nerd Fonts installed so prompt icons render: JetBrainsMono, FiraCode, CascadiaCode, and Hack (edit the `NERD_FONTS` list in `setup.ps1` to add or remove fonts)
- `setup.ps1` and `uninstall.ps1` that back up and restore your previous config

## Install & run

```pwsh
git clone --depth=1 https://github.com/hollali/powershellbox.git
cd powershellbox
pwsh -ExecutionPolicy Bypass -File ./setup.ps1
```

What happens: the script detects your package manager (winget, choco, scoop, apt, dnf, pacman, zypper, or brew), installs all dependencies including eza, Starship, Fastfetch, and the Nerd Fonts, then symlinks the configs into place. Existing files are renamed with a `.powershellbox-backup` suffix first, so nothing is lost. Re-running setup is safe: it does not clobber earlier backups.

Two steps after installing:

1. Set your terminal font to one of the installed Nerd Fonts (e.g. JetBrainsMono Nerd Font) — otherwise prompt icons render as boxes.
2. Open a new PowerShell. You should see the Fastfetch banner and the Starship prompt.

### Install options

```pwsh
pwsh -File ./setup.ps1 -DryRun      # show every action without changing anything
pwsh -File ./setup.ps1 -NoInstall   # refresh configs only, skip packages and fonts
pwsh -File ./setup.ps1 -Force       # re-download fonts even if already present
pwsh -File ./setup.ps1 -InstallDir /custom/path
```

`-NoInstall` is what `tbupdate` uses after pulling changes. On Windows, symlinks may
require Developer Mode or an elevated shell; setup falls back to copying the configs
and uninstall still cleans those up.

## Configuration

Create `~/.config/powershellbox/config.ps1` returning a hashtable:

```pwsh
@{
    Disabled = @('fetch', 'tools')
    Plugins  = @("$HOME/.config/powershellbox/my-plugin.ps1")
}
```

Available module names: `aliases`, `fs`, `git`, `net`, `info`, `tools`, `fetch`, `plugins`, `completions`.
`tools` covers zoxide, fzf and Starship. Use `Disabled = @('*')` to load no optional modules.

You can also disable modules without a config file:

```pwsh
$env:POWERSHELLBOX_DISABLE = 'fetch,tools'
```

Plugins are `.ps1` files auto-loaded from `~/.config/powershellbox/plugins/` in
alphabetical order, plus any paths listed in `Plugins`. They load after all built-in
helpers, so they can call `port`, `tbstatus`, etc.

To load helpers from a script instead of an interactive shell, set
`$env:POWERSHELLBOX_ALLOW_NONINTERACTIVE = 1` before sourcing the profile.

## Toolbox commands

| Command | Purpose |
| --- | --- |
| `tbversion` | Print the installed version |
| `tbstatus` | Report config links, installed tools, fonts and disabled modules |
| `tbmodules` | List modules and whether each is enabled |
| `tbupdate [-Force]` | Pull the source repo and refresh configs; `-Force` also re-runs the installer |
| `tbcompletion [-Path <file>]` | Print or save the argument-completion script for reuse |

## Verify, update & uninstall

The copies live in `~/.local/share/powershellbox`, and your dotfiles are symlinks to them.
Run `tbstatus` for a quick health check. Update the toolbox with `tbupdate`, or edit the
files in this repo and re-run `./setup.ps1 -NoInstall`.

```pwsh
pwsh -ExecutionPolicy Bypass -File ./uninstall.ps1
```

Restores any backups it made and removes the installed copies and fonts. Packages
(starship, fastfetch, fzf, ...) are left in place. `uninstall.ps1` also supports
`-DryRun` and `-InstallDir`.

## Tests

```pwsh
Install-Module Pester -Scope CurrentUser -Force
Invoke-Pester ./tests
```

CI runs the same suite on Linux, Windows and macOS.

## License

MIT. See `LICENSE`.
