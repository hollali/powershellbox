# PowerShellBox (custom edition)

A one-command PowerShell profile plus a linutil-style toolbox for Windows/Linux/macOS:
a tuned `Microsoft.PowerShell_profile.ps1`, the Starship prompt with swappable palettes,
a Fastfetch system-info banner, one-key app installers, a doctor check, and Nerd Fonts
so prompt icons render.

Inspired by [hollali/bashbox](https://github.com/hollali/bashbox) (MIT), ported to PowerShell.

## What you get

- A tuned PowerShell profile with generous history handling, git aliases, smarter `ls`/`ll`/`la`/`tree` via eza when available, and helpers like `port`, `serve`, `gclone`, `gitroot`, `path`, `killport`, `myip`, `weather`, `extract`, `mkcd`, `backup`, and `update`
- An `update()` helper that upgrades packages non-interactively across winget, choco, scoop, apt, dnf, pacman, zypper, and brew
- The Starship prompt with a Nord-style two-line layout (`starship.toml`); your username is always visible and the hostname appears over SSH
- Fastfetch as a system-info banner on every new shell, with its own config, an `ff` alias, and an opt-out switch (`$env:POWERSHELLBOX_NO_FETCH = 1`; it also stays off inside VS Code)
- Zoxide, fzf, and Neovim wired in when available
- Nerd Fonts installed so prompt icons render: JetBrainsMono, FiraCode, CascadiaCode, and Hack (edit the `NERD_FONTS` list in `setup.ps1` to add or remove fonts)
- `setup.ps1` and `uninstall.ps1` that back up and restore your previous config

## Install & run

```pwsh
git clone --depth=1 https://github.com/hollali/powershellbox.git
cd powershellbox
pwsh -ExecutionPolicy Bypass -File ./setup.ps1
```

What happens: the script detects your package manager (winget, choco, scoop, apt, dnf, pacman, zypper, or brew), installs all dependencies, Starship, Fastfetch, and the Nerd Fonts, then symlinks the configs into place. Existing files are renamed with a `.powershellbox-backup` suffix first, so nothing is lost.

Two steps after installing:

1. Set your terminal font to one of the installed Nerd Fonts (e.g. JetBrainsMono Nerd Font) — otherwise prompt icons render as boxes.
2. Open a new PowerShell. You should see the Fastfetch banner and the Starship prompt.

Verify everything: run `./uninstall.ps1` to fully remove (restores backups), or edit the files in this repo and re-run `./setup.ps1`. The copies live in `~/.local/share/powershellbox`, and your dotfiles are symlinks to them.

## Uninstall

```pwsh
pwsh -ExecutionPolicy Bypass -File ./uninstall.ps1
```

Restores any backups it made and removes the installed copies. Packages (starship, fastfetch, fzf, ...) are left in place.

## License

MIT. See `LICENSE`.
