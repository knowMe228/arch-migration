from __future__ import annotations

import queue
import threading
import tkinter as tk
from tkinter import messagebox, scrolledtext, ttk
from typing import Callable

from ..state import AppContext
from ..services.packages import PackageService
from ..services.releases import ReleaseService
from ..services.repo import RepoService
from ..services.restore import RestoreService
from ..services.sync import SyncService
from ..services.system_checks import SystemCheckService
from .panels.overview import OverviewPanel
from .panels.packages import PackagesPanel
from .panels.restore import RestorePanel
from .panels.settings import SettingsPanel
from .panels.sync import SyncPanel


class MainWindow:
    def __init__(self, context: AppContext) -> None:
        self.context = context
        self.repo = RepoService(context.repo_dir)
        self.packages = PackageService(self.repo, context.package_files)
        self.releases = ReleaseService(context)
        self.checks = SystemCheckService(context.home_dir)
        self.sync = SyncService(context, self.repo, self.packages, self.releases)
        self.restore = RestoreService(context, self.repo, self.checks, self.releases)
        self.root = tk.Tk()
        self.root.title("Pentest Environment Manager")
        self.root.geometry("1100x780")
        self.log_queue: queue.Queue[str] = queue.Queue()
        self.busy = False
        self.status_var = tk.StringVar(value="Ready")
        self._build()
        self.root.after(150, self._pump_logs)
        self.refresh_overview()

    def _build(self) -> None:
        container = ttk.Frame(self.root, padding=12)
        container.pack(fill="both", expand=True)

        notebook = ttk.Notebook(container)
        notebook.pack(fill="both", expand=True)

        self.overview_panel = OverviewPanel(notebook, on_refresh=self.refresh_overview)
        self.sync_panel = SyncPanel(notebook, actions={
            "refresh_packages": lambda: self.run_task("Refresh package lists", self.sync.refresh_package_lists),
            "sync_dotfiles": lambda: self.run_task("Sync dotfiles", self.sync.sync_dotfiles),
            "upload_snapshot": lambda: self.run_task("Upload pentest snapshot", self.sync.upload_pentest_snapshot),
            "stage": lambda: self.run_task("Stage changes", self.sync.stage),
            "commit": lambda: self.run_task("Create sync commit", self.sync.commit),
            "push": lambda: self.run_task("Push current branch", self.sync.push),
            "full_sync": lambda: self.run_task("Full sync", self.sync.full_sync),
        })
        self.restore_panel = RestorePanel(notebook, actions={
            "preflight": self.show_preflight,
            "install_packages": lambda: self.run_task("Install packages", self.restore.install_packages),
            "install_dotfiles": lambda: self.run_task("Install dotfiles", self.restore.install_dotfiles),
            "restore_snapshot": lambda: self.run_task("Restore pentest snapshot", self.restore.restore_pentest_snapshot),
            "full_restore": lambda: self.run_task("Full restore", self.restore.full_restore),
        })
        self.packages_panel = PackagesPanel(
            notebook,
            package_loaders={label: (lambda item=label: self.packages.read_text(item)) for label in self.context.package_files},
            package_savers={label: (lambda content, item=label: self._save_package(item, content)) for label in self.context.package_files},
        )
        self.settings_panel = SettingsPanel(notebook, self._load_repos, self._save_repos)

        notebook.add(self.overview_panel, text="Overview")
        notebook.add(self.sync_panel, text="Sync")
        notebook.add(self.restore_panel, text="Restore")
        notebook.add(self.packages_panel, text="Packages")
        notebook.add(self.settings_panel, text="Settings")

        log_frame = ttk.LabelFrame(container, text="Activity log", padding=8)
        log_frame.pack(fill="both", expand=False, pady=(12, 0))
        self.log_widget = scrolledtext.ScrolledText(log_frame, wrap="word", height=14, state="disabled")
        self.log_widget.pack(fill="both", expand=True)
        ttk.Label(container, textvariable=self.status_var).pack(anchor="w", pady=(8, 0))

    def run(self) -> None:
        self.root.mainloop()

    def _append_log(self, message: str) -> None:
        self.log_widget.configure(state="normal")
        self.log_widget.insert("end", message + "\n")
        self.log_widget.see("end")
        self.log_widget.configure(state="disabled")

    def _pump_logs(self) -> None:
        while True:
            try:
                message = self.log_queue.get_nowait()
            except queue.Empty:
                break
            self._append_log(message)
        self.root.after(150, self._pump_logs)

    def log(self, message: str) -> None:
        self.log_queue.put(message)

    def run_task(self, label: str, callback: Callable[..., object]) -> None:
        if self.busy:
            messagebox.showinfo("Busy", "Another task is still running.")
            return

        self.busy = True
        self.status_var.set(label)
        self.log(f"== {label} ==")

        def finish() -> None:
            self.busy = False
            self.status_var.set("Ready")
            self.refresh_overview()

        def worker() -> None:
            try:
                result = callback(log=self.log)
                if isinstance(result, str) and result:
                    self.log(result)
                self.log(f"Completed: {label}")
            except Exception as exc:  # noqa: BLE001
                self.log(f"ERROR: {exc}")
                self.root.after(0, lambda: messagebox.showerror(label, str(exc)))
            finally:
                self.root.after(0, finish)

        threading.Thread(target=worker, daemon=True).start()

    def refresh_overview(self) -> None:
        remote = self.repo.remote_url()
        try:
            release = self.releases.release_status(remote)
            assets = release.get("assets", [])
            asset_text = ", ".join(f"{asset.name} ({asset.size} bytes)" for asset in assets) if assets else "No assets found"
            release_status = str(release.get("status", "Unknown"))
        except Exception as exc:  # noqa: BLE001
            release_status = f"Unavailable ({exc})"
            asset_text = "Unknown"

        self.overview_panel.update_data({
            "repo_path": str(self.context.repo_dir),
            "branch": self.repo.current_branch(),
            "git_status": self.repo.status_short() or "clean",
            "remote": remote or "origin not configured",
            "token": "Detected" if self.checks.token_present() else "Missing",
            "release_status": release_status,
            "release_assets": asset_text,
            "last_commit": self.repo.last_commit() or "No commits yet",
        })
        self.settings_panel.update_metadata({
            "repo_path": str(self.context.repo_dir),
            "branch": self.repo.current_branch(),
            "remote": remote or "origin not configured",
            "release_tag": self.context.release_tag,
            "token_source": "Environment" if self.context.token_present else "GITHUB_TOKEN not present",
            "cache_dir": str(self.context.cache_dir),
            "pentest_dir": str(self.context.pentest_dir),
        })

    def show_preflight(self) -> None:
        summary = "\n".join(self.restore.run_preflight())
        self.log(summary)
        messagebox.showinfo("Restore preflight", summary)

    def _save_package(self, label: str, content: str) -> None:
        self.packages.save_text(label, content)
        self.log(f"Saved {label} package list.")
        self.refresh_overview()

    def _load_repos(self) -> str:
        path = self.context.settings_files["Optional repos"]
        return path.read_text(encoding="utf-8") if path.exists() else ""

    def _save_repos(self, content: str) -> None:
        path = self.context.settings_files["Optional repos"]
        path.write_text(content.rstrip("\n") + "\n" if content.strip() else "", encoding="utf-8")
        self.log("Saved repos.pentest.txt")
        self.refresh_overview()