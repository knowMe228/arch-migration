from __future__ import annotations

import os
import shutil
from pathlib import Path


class SystemCheckService:
    def __init__(self, home_dir: Path) -> None:
        self.home_dir = home_dir

    def command_available(self, name: str) -> bool:
        return shutil.which(name) is not None

    def detect_arch_linux(self) -> bool:
        os_release = Path("/etc/os-release")
        if not os_release.exists():
            return False
        return "ID=arch" in os_release.read_text(encoding="utf-8", errors="ignore")

    def token_present(self) -> bool:
        return bool(os.environ.get("GITHUB_TOKEN"))

    def build_restore_preflight(self) -> list[str]:
        messages: list[str] = []
        messages.append("Arch Linux detected." if self.detect_arch_linux() else "Host is not Arch Linux.")
        for command in ("git", "curl", "rsync", "pacman", "pipx", "flatpak", "tar", "zstd", "python3"):
            messages.append(f"{command}: {'available' if self.command_available(command) else 'missing'}")
        messages.append(f"GITHUB_TOKEN: {'present' if self.token_present() else 'missing'}")
        return messages