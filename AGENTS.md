# AGENTS.md — Pentest Environment Manager
 
## Project Overview
This repository is a **Portable Pentest Environment Manager** for Arch Linux + BlackArch.
It captures the full state of a pentester's working environment:
packages, tools, configs, and scripts — all version-controlled via Git.
 
Goal: `./sync.sh` saves everything. `./scripts/install_all.sh` restores everything.
No manual steps. No state loss. No secrets committed.
 
## Repository Layout
```
repo/
├── AGENTS.md
├── sync.sh                   # ← PRIMARY: save & push all state
├── pkglist.pacman.txt        # pacman -Qqen output
├── pkglist.aur.txt           # pacman -Qqem output
├── pkglist.pipx.txt          # pipx list --short output
├── pkglist.flatpak.txt       # flatpak list --app --columns=application output
├── dotfiles/
│   ├── .zshrc
│   ├── .p10k.zsh
│   ├── zellij/               # full zellij config dir
│   └── oh-my-zsh/            # only custom plugins & themes, NOT the whole install
├── pentest/                  # mirror of ~/pentest (whitelist-only via rsync)
└── scripts/
    ├── install_all.sh        # full environment restore from scratch
    ├── install_packages.sh
    ├── install_dotfiles.sh
    └── install_pentest.sh
```
 
## sync.sh — Exact Behavior
`sync.sh` MUST do these steps in order, with `set -euo pipefail`:
1. Update `pkglist.pacman.txt`  → `pacman -Qqen`
2. Update `pkglist.aur.txt`     → `pacman -Qqem`
3. Update `pkglist.pipx.txt`    → `pipx list --short`
4. Update `pkglist.flatpak.txt` → `flatpak list --app --columns=application`
5. Sync dotfiles:
   - `.zshrc`, `.p10k.zsh` from `$HOME`
   - `$HOME/.config/zellij/` → `dotfiles/zellij/`
   - `$HOME/.oh-my-zsh/custom/` → `dotfiles/oh-my-zsh/`
6. Sync `~/pentest/` → `pentest/` via rsync whitelist:
   - Allowed: `*.py`, `*.sh`, `*.md`, `*.txt`, `*.yaml`, `*.json`, `*.conf`, `*.toml`
   - Excluded: `*.pcap`, `*.cap`, `*.zip`, `*.tar*`, `*.bin`, `*.exe`, `node_modules/`, `.git/`
   - Max file size: 5MB
7. `git add -A`
8. `git commit -m "sync: $(date '+%Y-%m-%d %H:%M')"` — skip if nothing changed
9. `git push origin main`
 
sync.sh should print colored status per step (✔ / ✗) and exit non-zero on any failure.
 
## install_all.sh — Exact Behavior
`install_all.sh` MUST:
1. Check: running on Arch Linux. Abort with clear message if not.
2. Install BlackArch keyring if not present.
3. Run `install_packages.sh`:
   - `sudo pacman -S --needed --noconfirm` from `pkglist.pacman.txt`
   - AUR via `yay -S --needed --noconfirm` from `pkglist.aur.txt`
   - `pipx install` each package from `pkglist.pipx.txt`
   - `flatpak install -y` each from `pkglist.flatpak.txt`
4. Run `install_dotfiles.sh`:
   - Symlink or copy dotfiles with backup of existing (`~/.zshrc.bak-YYYYMMDD`)
5. Run `install_pentest.sh`:
   - rsync `pentest/` → `~/pentest/` preserving structure
 
## Code Style Rules
- All scripts: `#!/usr/bin/env bash` + `set -euo pipefail`
- Variables: `UPPER_SNAKE_CASE` for paths, lowercase for local vars
- Functions: descriptive names like `sync_dotfiles()`, `install_aur_packages()`
- Logging: use a helper `log_step()` that prints `[STEP N/M] message` in color
- No hardcoded paths: use variables (`REPO_DIR`, `DOTFILES_DIR`, `PENTEST_DIR`)
- No secrets: never commit tokens, passwords, API keys, SSH private keys
- Idempotent: scripts must be safe to run multiple times
 
## Security Rules (CRITICAL)
- Never add to `.gitignore` exceptions for: `*.key`, `*.pem`, `id_rsa*`, `.env`, `*_secret*`
- If you find secrets during sync, ABORT and warn the user — do not commit
- pentest/ rsync uses whitelist, NOT blacklist — when in doubt, exclude
 
## Testing
Before finalizing any script:
1. Run `bash -n scriptname.sh` (syntax check)
2. Run `shellcheck scriptname.sh` if shellcheck is available
3. Verify idempotency by mentally tracing a second run
4. Check that git operations handle "nothing to commit" gracefully
 
## What NOT to Do
- Do NOT recursively sync all of `$HOME` — whitelist only
- Do NOT touch `/etc/` or system-level configs unless explicitly asked
- Do NOT install AUR helper (yay) automatically — check if present, warn if missing
- Do NOT use `rm -rf` without confirmation prompt
- Do NOT create scripts longer than 200 lines — split into functions/files
 
## PR / Commit Format
Commits from sync.sh: `sync: YYYY-MM-DD HH:MM`
Manual commits: `feat:`, `fix:`, `refactor:`, `docs:` prefixes