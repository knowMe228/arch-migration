# Pentest Environment Manager

Portable, Git-tracked backup and restore workflow for an Arch Linux + BlackArch pentest workstation.

## Goal

- `./sync.sh` captures the current workstation state into this repository and GitHub Releases.
- `./scripts/install_all.sh` restores that state on a fresh Arch install.
- No manual backup steps after initial auth setup.
- No secrets committed.

## What Gets Tracked In Git

- Native packages from `pacman`
- AUR packages from `pacman -Qqem`
- `pipx` packages
- `flatpak` applications
- Shell dotfiles: `.zshrc`, `.p10k.zsh`
- `zellij` configuration from `~/.config/zellij/`
- `oh-my-zsh` custom plugins and themes from `~/.oh-my-zsh/custom/`
- Project scripts and metadata

## What Happens To `~/pentest`

`~/pentest` is no longer mirrored into the git repository.

Instead, `sync.sh`:

1. Scans `~/pentest` for likely secret filenames and text secrets
2. Creates a full compressed archive of the whole directory
3. Uploads the archive and its checksum to the GitHub Release tagged `pentest-latest`

This avoids bloating git history while still preserving the full workspace on GitHub.

## Requirements For Full Pentest Uploads

To upload release assets, `sync.sh` needs a GitHub token in the environment:

```bash
export GITHUB_TOKEN=your_github_token
```

The token should have permission to create releases and upload release assets for this repository.

## Repository Layout

```text
.
├── AGENTS.md
├── README.md
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
6. Archive and upload the full `~/pentest/` directory to GitHub Releases
7. Stage all git changes with `git add -A`
8. Commit changes using `sync: YYYY-MM-DD HH:MM`
9. Push to `origin main`

## How Restore Works

Run:

```bash
./scripts/install_all.sh
```

This will:

1. Verify the host is Arch Linux
2. Ensure the BlackArch keyring is installed
3. Install packages from the tracked package lists
4. Restore dotfiles with backups of existing files
5. Download the latest pentest archive from GitHub Releases and restore it into `~/pentest/`

## Optional Pentest Repositories

`repos.pentest.txt` is reserved for optional Git repositories you may want to clone back into `~/pentest/` later.

Current scripts do not auto-clone this file yet, but it is tracked now so the workflow can grow without changing the repository shape.

## Safety Notes

- Do not store secrets in tracked files.
- `sync.sh` aborts if it finds likely secrets in synced dotfiles or in `~/pentest` before archiving.
- Nested `.git` directories in synced dotfiles are excluded to avoid accidental submodule-like entries.
- `yay` is not installed automatically.
- Full pentest snapshots are kept out of git history and published as release assets instead.

## Validation

Before finalizing script changes:

```bash
bash -n sync.sh scripts/*.sh
shellcheck sync.sh scripts/*.sh
```

## Typical Workflow

```bash
export GITHUB_TOKEN=your_github_token
./sync.sh
```

On a fresh Arch machine:

```bash
git clone <your-repo-url>
cd pentest-env
./scripts/install_all.sh
```