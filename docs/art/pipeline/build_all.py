"""Rebuild every game asset, the mock screenshots and the documentation from the staged packs.

Order matters: tiles first (the Colossus rim uses the obsidian atlas), sprites before items (icon / splash use the hero).
Run with the project venv:  .tools/venv/Scripts/python.exe docs/art/pipeline/build_all.py
Inputs : .tools/asset_candidates/**            (staging area, not in git)
Outputs: assets/**, docs/art/mock_*.png, docs/ASSET_MANIFEST.md, CREDITS.md, assets/licenses/**
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
STEPS = ["build_tiles.py", "build_sprites.py", "build_env.py", "build_items.py", "build_audio.py", "build_licenses.py",
         "build_mocks.py", "build_manifest.py"]

if __name__ == "__main__":
    if "--clean" in sys.argv:
        shutil.rmtree(os.path.join(ROOT, "assets"), ignore_errors=True)
        reg = os.path.join(HERE, "registry.json")
        if os.path.exists(reg):
            os.remove(reg)
    for s in STEPS:
        print("==", s)
        subprocess.check_call([sys.executable, os.path.join(HERE, s)])
