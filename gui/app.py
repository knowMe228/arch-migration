from __future__ import annotations

from pathlib import Path

from .state import AppContext
from .views.main_window import MainWindow


def launch_app(repo_dir: Path) -> None:
    context = AppContext(repo_dir=repo_dir)
    window = MainWindow(context)
    window.run()