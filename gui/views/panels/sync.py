from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class SyncPanel(ttk.Frame):
    def __init__(self, master: tk.Misc, actions: dict[str, Callable[[], None]]) -> None:
        super().__init__(master, padding=12)
        self.actions = actions
        self._build()

    def _build(self) -> None:
        buttons = [
            ("Refresh package lists", self.actions["refresh_packages"]),
            ("Sync dotfiles", self.actions["sync_dotfiles"]),
            ("Upload pentest snapshot", self.actions["upload_snapshot"]),
            ("Stage", self.actions["stage"]),
            ("Commit", self.actions["commit"]),
            ("Push", self.actions["push"]),
            ("Full Sync", self.actions["full_sync"]),
        ]
        for index, (label, callback) in enumerate(buttons):
            ttk.Button(self, text=label, command=callback).grid(row=index // 2, column=index % 2, sticky="ew", padx=6, pady=6)
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=1)