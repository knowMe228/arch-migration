from __future__ import annotations

from pathlib import Path
from typing import Callable

from .repo import RepoService

LogFunc = Callable[[str], None]


class PackageService:
    def __init__(self, repo: RepoService, package_files: dict[str, Path]) -> None:
        self.repo = repo
        self.package_files = package_files

    def refresh_all(self, log: LogFunc | None = None) -> None:
        commands = {
            "Pacman": ["bash", "-lc", "pacman -Qqen > pkglist.pacman.txt"],
            "AUR": ["bash", "-lc", "pacman -Qqem > pkglist.aur.txt"],
            "pipx": ["bash", "-lc", "pipx list --short > pkglist.pipx.txt"],
            "Flatpak": ["bash", "-lc", "flatpak list --app --columns=application > pkglist.flatpak.txt"],
        }
        for label, command in commands.items():
            if log:
                log(f"Refreshing {label} package list...")
            self.repo.run_command(command, log=log)

    def read_text(self, label: str) -> str:
        return self.package_files[label].read_text(encoding="utf-8")

    def save_text(self, label: str, content: str) -> None:
        text = content.rstrip("\n") + "\n" if content.strip() else ""
        self.package_files[label].write_text(text, encoding="utf-8")