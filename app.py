#!/usr/bin/env python3
from pathlib import Path

from gui.app import launch_app


if __name__ == "__main__":
    launch_app(Path(__file__).resolve().parent)