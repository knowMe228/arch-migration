# Pentest Environment Manager

Portable, Git-tracked backup and restore workflow for an Arch Linux + BlackArch pentest workstation.

## Goal

- `./sync.sh` captures the current workstation state into this repository.
- `./scripts/install_all.sh` restores that state on a fresh Arch install.
- No manual backup steps.
- No secrets committed.

## What Gets Tracked

- Native packages from `pacman`
- AUR packages from `pacman -Qqem`
- `pipx` packages
- `flatpak` applications
- Shell dotfiles: `.zshrc`, `.p10k.zsh`
- `zellij` configuration from `~/.config/zellij/`
- `oh-my-zsh` custom plugins and themes from `~/.oh-my-zsh/custom/`
- A whitelist-only mirror of `~/pentest/`

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
6. Sync `~/pentest/` into `pentest/` using a whitelist-only `rsync`
7. Scan synced files for likely secrets
8. Stage all changes with `git add -A`
9. Commit changes using `sync: YYYY-MM-DD HH:MM`
10. Push to `origin main`

The pentest sync includes only these file types:

- `*.py`
- `*.sh`
- `*.md`
- `*.txt`
- `*.yaml`
- `*.json`
- `*.conf`
- `*.toml`

And excludes:

- `.git/`
- `node_modules/`
- `*.pcap`
- `*.cap`
- `*.zip`
- `*.tar*`
- `*.bin`
- `*.exe`
- files larger than 5 MB

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
5. Restore `pentest/` into `~/pentest/`

## Optional Pentest Repositories

`repos.pentest.txt` is reserved for optional Git repositories you may want to clone back into `~/pentest/` later.

Current scripts do not auto-clone this file yet, but it is tracked now so the workflow can grow without changing the repository shape.

## Safety Notes

- Do not store secrets in tracked files.
- `sync.sh` aborts if it finds likely secrets in synced content.
- Nested `.git` directories in synced dotfiles are excluded to avoid accidental submodule-like entries.
- `yay` is not installed automatically.

## Validation

Before finalizing script changes:

```bash
bash -n sync.sh scripts/*.sh
shellcheck sync.sh scripts/*.sh
```

## Typical Workflow

```bash
./sync.sh
```

On a fresh Arch machine:

```bash
git clone <your-repo-url>
cd pentest-env
./scripts/install_all.sh
```