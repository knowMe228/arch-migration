from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class SettingsPanel(ttk.Frame):
    def __init__(self, master: tk.Misc, load_repos: Callable[[], str], save_repos: Callable[[str], None]) -> None:
        super().__init__(master, padding=12)
        self.load_repos = load_repos
        self.save_repos = save_repos
        self.value_vars: dict[str, tk.StringVar] = {}
        self.text = tk.Text(self, wrap="none", height=16)
        self._build()

    def _build(self) -> None:
        fields = ["repo_path", "branch", "remote", "release_tag", "token_source", "cache_dir", "pentest_dir"]
        for row, key in enumerate(fields):
            ttk.Label(self, text=key.replace("_", " ").title() + ":", width=16).grid(row=row, column=0, sticky="nw", padx=(0, 8), pady=4)
            variable = tk.StringVar(value="-")
            self.value_vars[key] = variable
            ttk.Label(self, textvariable=variable, wraplength=760, justify="left").grid(row=row, column=1, sticky="w", pady=4)
        ttk.Label(self, text="repos.pentest.txt:").grid(row=len(fields), column=0, sticky="nw", padx=(0, 8), pady=(12, 4))
        self.text.grid(row=len(fields), column=1, sticky="nsew")
        button_row = ttk.Frame(self)
        button_row.grid(row=len(fields) + 1, column=1, sticky="w", pady=(8, 0))
        ttk.Button(button_row, text="Reload", command=self.reload).pack(side="left", padx=(0, 8))
        ttk.Button(button_row, text="Save", command=self.save).pack(side="left")
        self.columnconfigure(1, weight=1)
        self.rowconfigure(len(fields), weight=1)
        self.reload()

    def update_metadata(self, data: dict[str, str]) -> None:
        for key, variable in self.value_vars.items():
            variable.set(data.get(key, "-"))

    def reload(self) -> None:
        self.text.delete("1.0", "end")
        self.text.insert("1.0", self.load_repos())

    def save(self) -> None:
        self.save_repos(self.text.get("1.0", "end-1c"))