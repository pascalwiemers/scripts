#!/bin/bash
set -e

CONTAINER_NAME="hdri-box"
REPO_DIR="$HOME/DiffusionLight-Turbo"

echo "=== 1. Creating Distrobox with NVIDIA Passthrough ==="
if distrobox ls | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME already exists."
else
    distrobox create -n $CONTAINER_NAME --image ubuntu:22.04 --nvidia -Y
fi

echo "=== 2. Cloning Repository ==="
if [ ! -d "$REPO_DIR" ]; then
    git clone https://github.com/DiffusionLight/DiffusionLight-Turbo "$REPO_DIR"
fi

echo "=== 3. Configuring Internal Environment ==="
# We unset 'which' function to prevent that syntax error during the enter command
distrobox enter $CONTAINER_NAME -- bash -c "
    set -e
    # Fix for the 'which' error inherited from host
    unset -f which || true

    sudo apt update
    # Added zlib1g-dev to this list
    sudo apt install -y git wget libopenexr-dev build-essential libgl1-mesa-glx libglib2.0-0 libopenexr25 zlib1g-dev

    if [ ! -d \"\$HOME/miniconda3\" ]; then
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
        bash /tmp/miniconda.sh -b -p \"\$HOME/miniconda3\"
        rm /tmp/miniconda.sh
    fi

    source \"\$HOME/miniconda3/etc/profile.d/conda.sh\"
    cd \"$REPO_DIR\"

    if ! conda env list | grep -q \"diffusionlight-turbo\"; then
        conda env create -f environment.yml -n diffusionlight-turbo
    fi

    conda activate diffusionlight-turbo

    # Install dependencies
    pip install -r requirements.txt
    pip install OpenEXR==1.3.9

    echo 'Setup Complete!'
"

echo "=== 4. Setup Finished ==="
