#!/usr/bin/env python3
"""Compatibility launcher; the HTTP process is the Cangjie executable.

Prefer `bash scripts/workbench.sh`. Python is replaced via exec before serving.
"""
import os
from pathlib import Path
import sys

if __name__ == '__main__':
    launcher = Path(__file__).resolve().with_name('workbench.sh')
    os.execv('/bin/bash', ['bash', str(launcher), *sys.argv[1:]])
