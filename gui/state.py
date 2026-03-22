from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(slots=True)
class AppContext:
    repo_dir: Path
    release_tag: str = "pentest-latest"
    archive_name: str = "pentest-full.tar.zst"
    checksum_name: str = "pentest-full.tar.zst.sha256"
    home_dir: Path = field(default_factory=Path.home)

    @property
    def dotfiles_dir(self) -> Path:
        return self.repo_dir / "dotfiles"

    @property
    def pentest_dir(self) -> Path:
        return self.home_dir / "pentest"

    @property
    def cache_dir(self) -> Path:
        return self.home_dir / ".cache" / "pentest-env-gui"

    @property
    def package_files(self) -> dict[str, Path]:
        return {
            "Pacman": self.repo_dir / "pkglist.pacman.txt",
            "AUR": self.repo_dir / "pkglist.aur.txt",
            "pipx": self.repo_dir / "pkglist.pipx.txt",
            "Flatpak": self.repo_dir / "pkglist.flatpak.txt",
        }

    @property
    def settings_files(self) -> dict[str, Path]:
        return {"Optional repos": self.repo_dir / "repos.pentest.txt"}

    @property
    def token_present(self) -> bool:
        return bool(os.environ.get("GITHUB_TOKEN"))