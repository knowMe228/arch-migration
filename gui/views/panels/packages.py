from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class PackagesPanel(ttk.Frame):
    def __init__(self, master: tk.Misc, package_loaders: dict[str, Callable[[], str]], package_savers: dict[str, Callable[[str], None]]) -> None:
        super().__init__(master, padding=12)
        self.package_loaders = package_loaders
        self.package_savers = package_savers
        self.text_widgets: dict[str, tk.Text] = {}
        self._build()

    def _build(self) -> None:
        notebook = ttk.Notebook(self)
        notebook.grid(row=0, column=0, sticky="nsew")
        for label in self.package_loaders:
            frame = ttk.Frame(notebook, padding=8)
            text = tk.Text(frame, wrap="none", height=24)
            yscroll = ttk.Scrollbar(frame, orient="vertical", command=text.yview)
            xscroll = ttk.Scrollbar(frame, orient="horizontal", command=text.xview)
            text.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)
            text.grid(row=0, column=0, sticky="nsew")
            yscroll.grid(row=0, column=1, sticky="ns")
            xscroll.grid(row=1, column=0, sticky="ew")
            button_row = ttk.Frame(frame)
            button_row.grid(row=2, column=0, columnspan=2, sticky="ew", pady=(8, 0))
            ttk.Button(button_row, text="Reload", command=lambda name=label: self.reload_one(name)).pack(side="left", padx=(0, 8))
            ttk.Button(button_row, text="Save", command=lambda name=label: self.save_one(name)).pack(side="left")
            frame.columnconfigure(0, weight=1)
            frame.rowconfigure(0, weight=1)
            notebook.add(frame, text=label)
            self.text_widgets[label] = text
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)
        self.reload_all()

    def reload_one(self, label: str) -> None:
        widget = self.text_widgets[label]
        widget.delete("1.0", "end")
        widget.insert("1.0", self.package_loaders[label]())

    def save_one(self, label: str) -> None:
        widget = self.text_widgets[label]
        self.package_savers[label](widget.get("1.0", "end-1c"))

    def reload_all(self) -> None:
        for label in self.text_widgets:
            self.reload_one(label)