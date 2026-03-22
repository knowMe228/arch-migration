from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Callable

from ..state import AppContext
from .releases import ReleaseService
from .repo import RepoService
from .system_checks import SystemCheckService

LogFunc = Callable[[str], None]


class RestoreService:
    def __init__(self, context: AppContext, repo: RepoService, checks: SystemCheckService, releases: ReleaseService) -> None:
        self.context = context
        self.repo = repo
        self.checks = checks
        self.releases = releases

    def ensure_arch_linux(self) -> None:
        if not self.checks.detect_arch_linux():
            raise RuntimeError("This installer only supports Arch Linux.")

    def ensure_blackarch_keyring(self, log: LogFunc | None = None) -> None:
        result = self.repo.run_command(["bash", "-lc", "pacman -Q blackarch-keyring >/dev/null 2>&1"], check=False, log=log)
        if result.returncode == 0:
            if log:
                log("BlackArch keyring already installed.")
            return
        strap_path = "/tmp/blackarch-strap.sh"
        self.repo.run_command(["curl", "-fsSL", "https://blackarch.org/strap.sh", "-o", strap_path], log=log)
        self.repo.run_command(["chmod", "+x", strap_path], log=log)
        self.repo.run_command(["sudo", strap_path], log=log)

    def install_packages(self, log: LogFunc | None = None) -> None:
        self.repo.run_command(["bash", str(self.context.repo_dir / "scripts" / "install_packages.sh")], log=log)

    def _backup_path(self, target: Path) -> Path:
        return target.with_name(f"{target.name}.bak-{datetime.now().strftime('%Y%m%d')}")

    def _symlink_with_backup(self, source: Path, target: Path, log: LogFunc | None = None) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink() and target.resolve() == source.resolve():
            if log:
                log(f"Already linked: {target}")
            return
        if target.exists() or target.is_symlink():
            backup = self._backup_path(target)
            if backup.exists() or backup.is_symlink():
                raise RuntimeError(f"Backup already exists, refusing to overwrite: {backup}")
            target.rename(backup)
            if log:
                log(f"Backed up {target} -> {backup}")
        if target.exists() or target.is_symlink():
            target.unlink()
        target.symlink_to(source)

    def install_dotfiles(self, log: LogFunc | None = None) -> None:
        dotfiles = self.context.dotfiles_dir
        self._symlink_with_backup(dotfiles / ".zshrc", self.context.home_dir / ".zshrc", log=log)
        self._symlink_with_backup(dotfiles / ".p10k.zsh", self.context.home_dir / ".p10k.zsh", log=log)
        self._symlink_with_backup(dotfiles / "zellij", self.context.home_dir / ".config" / "zellij", log=log)
        self._symlink_with_backup(dotfiles / "oh-my-zsh", self.context.home_dir / ".oh-my-zsh" / "custom", log=log)

    def restore_pentest_snapshot(self, log: LogFunc | None = None) -> None:
        self.releases.download_latest_snapshot(self.repo.remote_url(), log=log)

    def run_preflight(self) -> list[str]:
        return self.checks.build_restore_preflight()

    def full_restore(self, log: LogFunc | None = None) -> None:
        self.ensure_arch_linux()
        self.ensure_blackarch_keyring(log=log)
        self.install_packages(log=log)
        self.install_dotfiles(log=log)
        self.restore_pentest_snapshot(log=log)