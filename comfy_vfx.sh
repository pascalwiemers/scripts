#!/bin/bash
# High-Performance Launcher
VENV_PY="$HOME/VFX_Comfy/venv/bin/python"
MAIN_PY="$HOME/VFX_Comfy/ComfyUI/main.py"

# VFX Production Flags
# --use-xformers: Massive speed boost for tiling upscales
# --disable-smart-memory: Keeps models in VRAM for faster sequence processing
"$VENV_PY" "$MAIN_PY" --highvram --use-xformers --port 8188
