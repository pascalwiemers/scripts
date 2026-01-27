#!/bin/bash
set -e

CONTAINER_NAME="pano-box"
REPO_DIR="$HOME/SD-T2I-360PanoImage"

echo "=== 1. Creating Distrobox with NVIDIA Passthrough ==="
if distrobox ls | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME already exists."
else
    distrobox create -n $CONTAINER_NAME --image ubuntu:22.04 --nvidia -Y
fi

echo "=== 2. Cloning Repository ==="
if [ ! -d "$REPO_DIR" ]; then
    git clone https://github.com/ArcherFMY/SD-T2I-360PanoImage.git "$REPO_DIR"
fi

echo "=== 3. Configuring Internal Environment ==="
# We unset 'which' function to prevent syntax error during the enter command
distrobox enter $CONTAINER_NAME -- bash -c "
    set -e
    unset -f which || true

    sudo apt update
    sudo apt install -y git wget build-essential libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 libopenexr-dev

    if [ ! -d \"\$HOME/miniconda3\" ]; then
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
        bash /tmp/miniconda.sh -b -p \"\$HOME/miniconda3\"
        rm /tmp/miniconda.sh
    fi

    source \"\$HOME/miniconda3/etc/profile.d/conda.sh\"
    cd \"$REPO_DIR\"

    if ! conda env list | grep -q \"pano-env\"; then
        conda create -n pano-env python=3.10 -y
    fi

    conda activate pano-env

    # Install dependencies
    pip install -r requirements.txt
    # Downgrade libraries to be compatible with diffusers 0.26.0 (Feb 2024 era)
    # huggingface_hub < 0.25.0 to support cached_download
    # transformers < 4.39.0 to support huggingface_hub < 0.25.0
    pip install 'huggingface_hub<0.25.0' 'transformers<4.39.0'
    
    # Patch basicsr to work with newer torchvision (fixes ModuleNotFoundError: No module named 'torchvision.transforms.functional_tensor')
    # We find where basicsr is installed and patch the degradations.py file
    SITE_PACKAGES=\$(python3 -c \"import site; print(site.getsitepackages()[0])\")
    if [ -f \"\$SITE_PACKAGES/basicsr/data/degradations.py\" ]; then
        echo \"Patching basicsr/data/degradations.py...\"
        sed -i \"s/from torchvision.transforms.functional_tensor import rgb_to_grayscale/from torchvision.transforms.functional import rgb_to_grayscale/g\" \"\$SITE_PACKAGES/basicsr/data/degradations.py\"
    fi
    
    echo '=== Downloading Models ==='
    if [ ! -d \"models\" ]; then
        mkdir -p models
        echo 'Attempting to download models from HuggingFace (ArcherFMY/Diffusion360)...'
        
        # Try downloading via python script to avoid CLI auth issues if public, or print clearer manual instructions
        python3 -c \"
from huggingface_hub import snapshot_download
import os
try:
    print('Downloading models...')
    snapshot_download(repo_id='ArcherFMY/Diffusion360', local_dir='models', local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
    print('Download complete.')
except Exception as e:
    print(f'Error: {e}')
    print('Please download models manually from: https://huggingface.co/ArcherFMY/Diffusion360')
\"
    else
        echo 'Models directory exists. Skipping download.'
    fi

    echo 'Setup Complete!'
"

echo "=== 4. Setup Finished ==="
