from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class RestorePanel(ttk.Frame):
    def __init__(self, master: tk.Misc, actions: dict[str, Callable[[], None]]) -> None:
        super().__init__(master, padding=12)
        self.actions = actions
        self._build()

    def _build(self) -> None:
        buttons = [
            ("Run full restore preflight", self.actions["preflight"]),
            ("Install packages", self.actions["install_packages"]),
            ("Install dotfiles", self.actions["install_dotfiles"]),
            ("Restore pentest snapshot", self.actions["restore_snapshot"]),
            ("Full Restore", self.actions["full_restore"]),
        ]
        for row, (label, callback) in enumerate(buttons):
            ttk.Button(self, text=label, command=callback).grid(row=row, column=0, sticky="ew", padx=6, pady=6)
        self.columnconfigure(0, weight=1)