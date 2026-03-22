from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class OverviewPanel(ttk.Frame):
    def __init__(self, master: tk.Misc, on_refresh: Callable[[], None]) -> None:
        super().__init__(master, padding=12)
        self.on_refresh = on_refresh
        self.values: dict[str, tk.StringVar] = {}
        self._build()

    def _build(self) -> None:
        fields = [
            ("Repository", "repo_path"),
            ("Branch", "branch"),
            ("Git status", "git_status"),
            ("Remote", "remote"),
            ("GITHUB_TOKEN", "token"),
            ("Release status", "release_status"),
            ("Release assets", "release_assets"),
            ("Last commit", "last_commit"),
        ]
        for row, (label, key) in enumerate(fields):
            ttk.Label(self, text=label + ":", width=16).grid(row=row, column=0, sticky="nw", padx=(0, 8), pady=4)
            variable = tk.StringVar(value="-")
            self.values[key] = variable
            ttk.Label(self, textvariable=variable, wraplength=760, justify="left").grid(row=row, column=1, sticky="w", pady=4)
        ttk.Button(self, text="Refresh overview", command=self.on_refresh).grid(row=len(fields), column=0, columnspan=2, sticky="w", pady=(12, 0))
        self.columnconfigure(1, weight=1)

    def update_data(self, data: dict[str, str]) -> None:
        for key, value in data.items():
            if key in self.values:
                self.values[key].set(value)