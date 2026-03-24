# Pentest Environment Manager

Portable, Git-tracked backup and restore workflow for an Arch Linux + BlackArch pentest workstation.

## Goal

- `./sync.sh` captures the current workstation state into this repository and GitHub Releases.
- `./scripts/install_all.sh` restores that state on a fresh Arch install.
- `python app.py` provides a desktop GUI for the same repository workflows.
- No manual backup steps after initial auth setup.
- No secrets committed.

## Interfaces

This repository currently exposes two ways to work with the environment manager:

- CLI: `./sync.sh` and `./scripts/install_all.sh`
- Desktop GUI: `python app.py`

The bash scripts remain the canonical CLI path. The GUI is an additional management surface and currently lives on a separate Git branch during development.

## GUI Requirements

- Python 3.11 or newer
- Tkinter available in the Python install
- `GITHUB_TOKEN` exported in the shell or desktop session before launch if you want release upload and restore actions to work

Example:

```bash
export GITHUB_TOKEN=your_github_token
python app.py
```

The GUI reads `GITHUB_TOKEN` from the environment only. It does not store tokens in files.

## What Gets Tracked In Git

- Native packages from `pacman`
- AUR packages from `pacman -Qqem`
- `pipx` packages
- `flatpak` applications
- Shell dotfiles: `.zshrc`, `.p10k.zsh`
- `zellij` configuration from `~/.config/zellij/`
- full `oh-my-zsh` directory from `~/.oh-my-zsh/`
- XFCE visual state: panels, launchers, themes/icons, desktop shortcuts
- Project scripts, GUI sources, and metadata

## What Happens To `~/pentest`

`~/pentest` is no longer mirrored into the git repository.

Instead, `sync.sh` and the GUI:

1. Scan `~/pentest` for likely secret filenames and text secrets
2. Create a full compressed archive of the whole directory
3. Upload the archive and its checksum to the GitHub Release tagged `pentest-latest`

This avoids bloating git history while still preserving the full workspace on GitHub.

## Requirements For Full Pentest Uploads

To upload release assets, the CLI and GUI both need a GitHub token in the environment:

```bash
export GITHUB_TOKEN=your_github_token
```

The token should have permission to create releases and upload release assets for this repository.

## Repository Layout

```text
.
├── AGENTS.md
├── README.md
├── app.py
├── gui/
├── sync.sh
├── pkglist.pacman.txt
├── pkglist.aur.txt
├── pkglist.pipx.txt
├── pkglist.flatpak.txt
├── repos.pentest.txt
├── dotfiles/
├── pentest/
└── scripts/
```

## How `sync.sh` Works

`sync.sh` runs in strict bash mode and performs these steps in order:

1. Export pacman package list to `pkglist.pacman.txt`
2. Export AUR package list to `pkglist.aur.txt`
3. Export pipx package list to `pkglist.pipx.txt`
4. Export Flatpak app list to `pkglist.flatpak.txt`
5. Sync dotfiles into `dotfiles/`
6. Sync XFCE desktop state into `desktop-state/xfce/`
7. Archive and upload the full `~/pentest/` directory to GitHub Releases
8. Stage all git changes with `git add -A`
9. Commit changes using `sync: YYYY-MM-DD HH:MM`
10. Push to `origin main`

## What The GUI Can Do

The desktop app provides a single-window control panel with these tabs:

- `Overview`: repo path, branch, git status, token visibility, release snapshot status, last commit
- `Sync`: refresh package lists, sync dotfiles, upload pentest snapshot, stage, commit, push, or run a full sync
- `Restore`: run preflight checks, install packages, install dotfiles, restore the pentest snapshot, or run a full restore
- `Packages`: edit and save the tracked package list files
- `Settings`: edit `repos.pentest.txt` and inspect the active repo paths and release tag

The GUI intentionally does not edit raw dotfiles, change branches, or mutate git remotes.

## How Restore Works

Run:

```bash
./scripts/install_all.sh
```

Or launch the GUI and use the `Restore` tab.

Restore will:

1. Verify the host is Arch Linux
2. Ensure the BlackArch keyring is installed
3. Install packages from the tracked package lists
4. Restore dotfiles with backups of existing files
5. Restore XFCE desktop state from `desktop-state/xfce/`
6. Download the latest pentest archive from GitHub Releases and restore it into `~/pentest/`

## Optional Pentest Repositories

`repos.pentest.txt` is reserved for optional Git repositories you may want to clone back into `~/pentest/` later.

Current scripts and GUI do not auto-clone this file yet, but it is tracked now so the workflow can grow without changing the repository shape.

## Safety Notes

- Do not store secrets in tracked files.
- `sync.sh` and the GUI abort if they find likely secrets in synced dotfiles or in `~/pentest` before archiving.
- Nested `.git` directories in synced dotfiles are excluded to avoid accidental submodule-like entries.
- `yay` is not installed automatically.
- Full pentest snapshots are kept out of git history and published as release assets instead.

## Validation

Before finalizing script changes:

```bash
bash -n sync.sh scripts/*.sh
shellcheck sync.sh scripts/*.sh
python -m py_compile app.py $(find gui -name '*.py' | sort)
```

## Typical Workflow

```bash
export GITHUB_TOKEN=your_github_token
./sync.sh
```

Or with the GUI:

```bash
export GITHUB_TOKEN=your_github_token
python app.py
```

On a fresh Arch machine:

```bash
git clone <your-repo-url>
cd pentest-env
./scripts/install_all.sh
```
## Remote Arsenal Inventory Flow

Use this when you want to clone the same tool arsenal from another Arch/BlackArch host.

1. Run inventory against the source host:

```bash
./scripts/inventory_remote_tools.sh --host 192.168.0.176 --user kali
```

2. Review generated artifacts in repo root:

- `pkglist.pacman.txt`
- `pkglist.aur.txt`
- `pkglist.pipx.txt`
- `pkglist.flatpak.txt`
- `pkglist.blackarch.txt`
- `arsenal.manual.csv`
- `arsenal.report.md`

3. On a fresh Arch/BlackArch system, restore with:

```bash
./scripts/install_all.sh
```

`install_all.sh` applies package manifests automatically and prints a warning for tools listed in `arsenal.manual.csv`, which require manual follow-up.
