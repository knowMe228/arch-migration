from __future__ import annotations

import os
import re
import shutil
from pathlib import Path
from typing import Callable

from ..state import AppContext
from .packages import PackageService
from .releases import ReleaseService
from .repo import RepoService

LogFunc = Callable[[str], None]
SECRET_NAME_PATTERNS = ("*.key", "*.pem", "id_rsa*", ".env", "*_secret*")
SECRET_CONTENT_RE = re.compile(r"BEGIN [A-Z ]*PRIVATE KEY|api[_-]?key\s*[:=]|token\s*[:=]|password\s*[:=]|AKIA[0-9A-Z]{16}")


class SyncService:
    def __init__(self, context: AppContext, repo: RepoService, packages: PackageService, releases: ReleaseService) -> None:
        self.context = context
        self.repo = repo
        self.packages = packages
        self.releases = releases

    def _sync_directory(self, source: Path, destination: Path, log: LogFunc | None = None) -> None:
        if destination.exists():
            shutil.rmtree(destination)
        destination.mkdir(parents=True, exist_ok=True)
        for root, dirs, files in os.walk(source):
            dirs[:] = [name for name in dirs if name != ".git"]
            root_path = Path(root)
            rel_root = root_path.relative_to(source)
            dest_root = destination / rel_root
            dest_root.mkdir(parents=True, exist_ok=True)
            for file_name in files:
                shutil.copy2(root_path / file_name, dest_root / file_name)
        if log:
            log(f"Synced directory {source} -> {destination}")

    def sync_dotfiles(self, log: LogFunc | None = None) -> None:
        self.context.dotfiles_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.context.home_dir / ".zshrc", self.context.dotfiles_dir / ".zshrc")
        shutil.copy2(self.context.home_dir / ".p10k.zsh", self.context.dotfiles_dir / ".p10k.zsh")
        self._sync_directory(self.context.home_dir / ".config" / "zellij", self.context.dotfiles_dir / "zellij", log=log)
        self._sync_directory(self.context.home_dir / ".oh-my-zsh" / "custom", self.context.dotfiles_dir / "oh-my-zsh", log=log)

    def scan_for_secrets(self, scan_dir: Path) -> None:
        for pattern in SECRET_NAME_PATTERNS:
            if next(scan_dir.rglob(pattern), None):
                raise RuntimeError(f"Potential secret filename detected matching pattern: {pattern}")
        for path in scan_dir.rglob("*"):
            if not path.is_file():
                continue
            content = path.read_text(encoding="utf-8", errors="ignore")
            if SECRET_CONTENT_RE.search(content):
                raise RuntimeError(f"Potential secret content detected in {path}")

    def refresh_package_lists(self, log: LogFunc | None = None) -> None:
        self.packages.refresh_all(log=log)

    def upload_pentest_snapshot(self, log: LogFunc | None = None) -> None:
        self.scan_for_secrets(self.context.pentest_dir)
        self.releases.upload_latest_snapshot(self.repo.remote_url(), log=log)

    def stage(self, log: LogFunc | None = None) -> None:
        self.repo.stage_all(log=log)

    def commit(self, log: LogFunc | None = None) -> str:
        return self.repo.create_sync_commit_if_needed(log=log)

    def push(self, log: LogFunc | None = None) -> None:
        self.repo.push_current_branch(log=log)

    def full_sync(self, log: LogFunc | None = None) -> None:
        if log:
            log("Starting full GUI-managed sync...")
        self.refresh_package_lists(log=log)
        self.sync_dotfiles(log=log)
        self.scan_for_secrets(self.context.dotfiles_dir)
        self.upload_pentest_snapshot(log=log)
        self.stage(log=log)
        self.commit(log=log)
        if log:
            log("Full sync completed. Push remains a separate explicit action.")