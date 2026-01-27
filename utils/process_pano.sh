#!/bin/bash
# @kde

# 1. Capture original info
INPUT_PATH=$(realpath "$1")
ORIGINAL_DIR=$(dirname "$INPUT_PATH")
ORIGINAL_FILENAME=$(basename "$INPUT_PATH")
ORIGINAL_BASENAME="${ORIGINAL_FILENAME%.*}"
EXTENSION="${INPUT_PATH##*.}"

# 2. Setup standard naming
TEMP_ID=$(date +%s)
PROC_DIR="/tmp/pano_proc_$TEMP_ID"
STAGED_INPUT_NAME="input_standard.$EXTENSION"

# Load Config
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEPLOYED_CONFIG="$SCRIPT_DIR/process_pano_config.env"
# Point to source config for live editing (optional, matching previous pattern)
SOURCE_CONFIG="/home/mini2/scripts/utils/process_pano_config.env"

if [ -f "$SOURCE_CONFIG" ]; then
    source "$SOURCE_CONFIG"
elif [ -f "$DEPLOYED_CONFIG" ]; then
    source "$DEPLOYED_CONFIG"
fi

# Defaults
PROMPT=${PROMPT:-"A living room"}
I2P_PROMPT=${I2P_PROMPT:-$PROMPT}
UPSCALE=${UPSCALE:-"False"}
OUTPUT_DIR=${OUTPUT_DIR:-$ORIGINAL_DIR}

# Container and Repo
CONTAINER_NAME="pano-box"
REPO_DIR="$HOME/SD-T2I-360PanoImage"

echo "=== Processing Pano ==="
echo "Repo: $REPO_DIR"

# 3. Prepare Logic
if [ -f "$INPUT_PATH" ]; then
    echo "Mode: Image-to-Pano"
    MODE="img2pano"
    
    # Python script for Img2Pano
    # We construct it dynamically
    PYTHON_SCRIPT="
import torch
import sys
import os

# Add repo dir to sys.path to find modules like img2panoimg
repo_dir = '$REPO_DIR'
sys.path.append(repo_dir)

from img2panoimg import Image2360PanoramaImagePipeline

model_id = os.path.join(repo_dir, 'models')
if not os.path.exists(model_id):
    print(f'ERROR: Models directory not found: {model_id}')
    print('Please download models from the repository README and place them in:')
    print(f'  {model_id}')
    print('Required subdirectories: sd-i2p (for image-to-pano), sd-base (for text-to-pano)')
    exit(1)

# Check for required model subdirectory
i2p_model_path = os.path.join(model_id, 'sd-i2p')
if not os.path.exists(i2p_model_path) or not os.path.exists(os.path.join(i2p_model_path, 'config.json')):
    print(f'ERROR: Model subdirectory not found or incomplete: {i2p_model_path}')
    print('Expected structure: models/sd-i2p/config.json')
    print('Please download models from the repository README:')
    print('  https://github.com/ArcherFMY/SD-T2I-360PanoImage')
    print(f'  And extract to: {model_id}')
    exit(1)

print(f'Loading models from {model_id}')

try:
    pipe = Image2360PanoramaImagePipeline(model_id, torch_dtype=torch.float16)
except Exception as e:
    print(f'Error loading model: {e}')
    print(f'Ensure models are correctly downloaded to: {model_id}')
    print('Required: models/sd-i2p/ with config.json and model files')
    exit(1)

# Pipe to cuda
pipe.to('cuda')

image_path = '$PROC_DIR/in/$STAGED_INPUT_NAME'
# Use default mask from repo data if exists, else we need a strategy
mask_path = os.path.join(repo_dir, 'data', 'i2p-mask.jpg')

print(f'Input Image: {image_path}')
print(f'Input Mask: {mask_path}')

image = load_image(image_path).resize((512, 512))
# Ensure mask exists
if os.path.exists(mask_path):
    mask = load_image(mask_path)
else:
    print('Warning: Default mask not found. Creating a dummy mask.')
    from PIL import Image
    mask = Image.new('RGB', (512, 512), (255, 255, 255)) # All white (replace all?)

prompt = '$I2P_PROMPT'
upscale = $UPSCALE

input_data = {'prompt': prompt, 'image': image, 'mask': mask, 'upscale': upscale}
output = pipe(input_data)

output_path = '$PROC_DIR/out/result.png'
output.save(output_path)
print(f'Saved to {output_path}')
"

else
    echo "Mode: Text-to-Pano"
    MODE="txt2pano"
    
    # Prompt for text if not provided or just use config?
    # Let's try to ask user if kdialog exists
    if command -v kdialog &> /dev/null; then
        USER_PROMPT=$(kdialog --inputbox "Enter Prompt for 360 Panorama:" "$PROMPT")
        if [ -n "$USER_PROMPT" ]; then
            PROMPT="$USER_PROMPT"
        fi
    fi

    PYTHON_SCRIPT="
import torch
import sys
import os

# Add repo dir to sys.path to find modules like txt2panoimg
repo_dir = '$REPO_DIR'
sys.path.append(repo_dir)

from txt2panoimg import Text2360PanoramaImagePipeline

model_id = os.path.join(repo_dir, 'models')
if not os.path.exists(model_id):
    print(f'ERROR: Models directory not found: {model_id}')
    print('Please download models from the repository README and place them in:')
    print(f'  {model_id}')
    print('Required subdirectories: sd-base (for text-to-pano)')
    exit(1)

# Check for required model subdirectory
t2p_model_path = os.path.join(model_id, 'sd-base')
if not os.path.exists(t2p_model_path) or not os.path.exists(os.path.join(t2p_model_path, 'config.json')):
    print(f'ERROR: Model subdirectory not found or incomplete: {t2p_model_path}')
    print('Expected structure: models/sd-base/config.json')
    print('Please download models from the repository README:')
    print('  https://github.com/ArcherFMY/SD-T2I-360PanoImage')
    print(f'  And extract to: {model_id}')
    exit(1)

print(f'Loading models from {model_id}')

try:
    pipe = Text2360PanoramaImagePipeline(model_id, torch_dtype=torch.float16)
except Exception as e:
    print(f'Error loading model: {e}')
    print(f'Ensure models are correctly downloaded to: {model_id}')
    print('Required: models/sd-base/ with config.json and model files')
    exit(1)

# Pipe to cuda
pipe.to('cuda')

prompt = '$PROMPT'
upscale = $UPSCALE

print(f'Prompt: {prompt}')

input_data = {'prompt': prompt, 'upscale': upscale}
output = pipe(input_data)

output_path = '$PROC_DIR/out/result.png'
output.save(output_path)
print(f'Saved to {output_path}')
"
fi

# 4. Construct Distrobox Command
CMD="
source \$HOME/miniconda3/etc/profile.d/conda.sh
conda activate pano-env
cd $REPO_DIR

# Create temp dirs
mkdir -p $PROC_DIR/in $PROC_DIR/out

# If input file, copy it
if [ '$MODE' == 'img2pano' ]; then
    cp '$INPUT_PATH' '$PROC_DIR/in/$STAGED_INPUT_NAME'
fi

# Run Python Script
echo \"$PYTHON_SCRIPT\" > $PROC_DIR/run_pano.py
python $PROC_DIR/run_pano.py

# Move result back
if [ -f '$PROC_DIR/out/result.png' ]; then
    # Rename based on input or prompt
    if [ '$MODE' == 'img2pano' ]; then
        mv '$PROC_DIR/out/result.png' '$OUTPUT_DIR/${ORIGINAL_BASENAME}_pano.png'
    else
        TIMESTAMP=\$(date +%s)
        mv '$PROC_DIR/out/result.png' '$OUTPUT_DIR/pano_\$TIMESTAMP.png'
    fi
    echo 'SUCCESS'
else
    echo 'FAILURE: Output not found'
fi
"

# 5. Launch
konsole --hold -e distrobox enter $CONTAINER_NAME -- bash -c "$CMD"

# Cleanup (optional, currently relying on /tmp/ cleanup or manual)
# rm -rf $PROC_DIR

