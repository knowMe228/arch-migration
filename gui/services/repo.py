from __future__ import annotations

import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable

LogFunc = Callable[[str], None]


@dataclass(slots=True)
class CommandResult:
    stdout: str
    stderr: str
    returncode: int


class RepoService:
    def __init__(self, repo_dir: Path) -> None:
        self.repo_dir = repo_dir

    def run_command(self, command: list[str], *, log: LogFunc | None = None, env: dict[str, str] | None = None, check: bool = True) -> CommandResult:
        if log:
            log(f"$ {' '.join(command)}")
        process = subprocess.run(command, cwd=self.repo_dir, text=True, capture_output=True, env=env, check=False)
        if log and process.stdout.strip():
            log(process.stdout.rstrip())
        if log and process.stderr.strip():
            log(process.stderr.rstrip())
        if check and process.returncode != 0:
            raise RuntimeError(f"Command failed ({process.returncode}): {' '.join(command)}")
        return CommandResult(process.stdout, process.stderr, process.returncode)

    def current_branch(self) -> str:
        return self.run_command(["git", "branch", "--show-current"]).stdout.strip()

    def remote_url(self) -> str:
        return self.run_command(["git", "remote", "get-url", "origin"], check=False).stdout.strip()

    def status_short(self) -> str:
        return self.run_command(["git", "status", "--short"]).stdout.strip()

    def is_dirty(self) -> bool:
        return bool(self.status_short())

    def last_commit(self) -> str:
        return self.run_command(["git", "log", "--oneline", "-1"], check=False).stdout.strip()

    def stage_all(self, log: LogFunc | None = None) -> None:
        self.run_command(["git", "add", "-A"], log=log)

    def create_sync_commit_if_needed(self, log: LogFunc | None = None) -> str:
        result = self.run_command(["git", "diff", "--cached", "--quiet", "--ignore-submodules", "--"], check=False)
        if result.returncode == 0:
            if log:
                log("No staged changes detected; skipping commit.")
            return "No changes detected; commit skipped."
        if result.returncode not in (0, 1):
            raise RuntimeError("Unable to determine staged git changes.")
        message = f"sync: {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        self.run_command(["git", "commit", "-m", message], log=log)
        return message

    def push_current_branch(self, log: LogFunc | None = None) -> None:
        branch = self.current_branch()
        self.run_command(["git", "push", "-u", "origin", branch], log=log)