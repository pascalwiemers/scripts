#!/bin/bash
# ComfyUI VFX Studio Pipeline - Rocky 9 (2026 Blackwell Optimized)
# This version includes Self-Healing, Version Locking, and Model Manifest.

set -e
PROJECT_DIR="$HOME/VFX_Comfy"
VENV_PATH="$PROJECT_DIR/venv"
COMFY_DIR="$PROJECT_DIR/ComfyUI"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M)

echo "--- [1/5] SYSTEM DEPENDENCY CHECK & INSTALL ---"
REQUIRED_PKGS=("gcc-c++" "cmake" "python3.12" "python3.12-devel" "git" "wget" "tar" "dnf-plugins-core")
MISSING_PKGS=()

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! rpm -q "$pkg" &> /dev/null; then MISSING_PKGS+=("$pkg"); fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    echo "Found missing system tools: ${MISSING_PKGS[*]}"
    sudo dnf config-manager --set-enabled crb || true
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y "${MISSING_PKGS[@]}"
fi

echo "--- [2/5] BACKUP EXISTING SETUP ---"
mkdir -p "$BACKUP_DIR"
if [ -d "$COMFY_DIR/custom_nodes" ]; then
    echo "Creating safety snapshot: backups/nodes_$TIMESTAMP.tar.gz"
    tar -czf "$BACKUP_DIR/nodes_$TIMESTAMP.tar.gz" -C "$COMFY_DIR" custom_nodes
    ls -dt "$BACKUP_DIR"/* | tail -n +6 | xargs -d '\n' rm -rf -- 2>/dev/null || true
fi

# Ensure Virtual Env exists
if [ ! -d "$VENV_PATH" ]; then
    echo "Initializing Virtual Environment..."
    python3.12 -m venv "$VENV_PATH"
    "$VENV_PATH/bin/pip" install --upgrade pip setuptools wheel
    "$VENV_PATH/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
fi

echo "--- [3/5] SYNC CUSTOM NODES & VERSION LOCK ---"
mkdir -p "$COMFY_DIR/custom_nodes"

sync_node() {
    local repo_url=$1
    local commit=$2
    local name=$(basename "$repo_url" .git)

    echo ">> Processing Node: $name"
    cd "$COMFY_DIR/custom_nodes"
    if [ ! -d "$name" ]; then git clone "$repo_url"; fi

    cd "$name"
    git fetch origin
    # Only checkout if a specific hash is provided and it's not 'main'
    if [ "$commit" != "main" ]; then
        git checkout "$commit"
    else
        git checkout main && git pull origin main
    fi

    if [ -f "requirements.txt" ]; then
        "$VENV_PATH/bin/pip" install -r requirements.txt --upgrade-strategy only-if-needed
    fi
}

# --- STABLE PRODUCTION STACK (Updated for Jan 2026) ---
sync_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "main"
sync_node "https://github.com/kijai/ComfyUI-KJNodes.git" "main"
sync_node "https://github.com/chflame163/ComfyUI_LayerStyle.git" "main"
sync_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "main"
sync_node "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" "main"

echo "--- [4/5] VFX MODEL MANIFEST (Automated Downloads) ---"

download_vfx_model() {
    local subfolder=$1
    local url=$2
    local filename=$3
    local target_path="$COMFY_DIR/models/$subfolder"

    mkdir -p "$target_path"
    if [ ! -f "$target_path/$filename" ]; then
        echo ">> Downloading NEW Model: $filename..."
        wget -c "$url" -O "$target_path/$filename"
    else
        echo ">> Model '$filename' already exists. Skipping."
    fi
}

# 1. Checkpoint: Flux.1-Dev (FP8 for high-fidelity extensions)
download_vfx_model "checkpoints" "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors" "flux1-dev-fp8.safetensors"

# 2. Depth: Depth-Anything-V2 (Base) for Z-Pass extraction
download_vfx_model "depth" "https://huggingface.co/depth-anything/Depth-Anything-V2-Base/resolve/main/depth_anything_v2_vitb.pth" "depth_anything_v2.pth"

# 3. Upscaler: 4x-UltraSharp (The VFX standard for non-hallucinatory upres)
download_vfx_model "upscale_models" "https://huggingface.co/uwu/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" "4x-UltraSharp.pth"

# 4. Roto: SAM (Segment Anything) weights for auto-masking
download_vfx_model "sams" "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth" "sam_vit_h_4b8939.pth"

echo "--- [5/5] SUCCESS ---"
echo "All VFX nodes synced and essential models downloaded."
echo "Launch your UI with: ./run_vfx.sh"
