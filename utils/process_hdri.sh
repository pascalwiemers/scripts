#!/bin/bash
# @kde

# 1. Capture original info
INPUT_PATH=$(realpath "$1")
ORIGINAL_DIR=$(dirname "$INPUT_PATH")
ORIGINAL_FILENAME=$(basename "$INPUT_PATH")
ORIGINAL_BASENAME="${ORIGINAL_FILENAME%.*}"
EXTENSION="${INPUT_PATH##*.}"

# 2. Setup standard naming for the pipeline
TEMP_ID=$(date +%s)
PROC_DIR="/tmp/hdri_proc_$TEMP_ID"
STAGED_INPUT_NAME="input_standard.$EXTENSION"

# Load Configuration
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEPLOYED_CONFIG="$SCRIPT_DIR/process_hdri_config.env"
# Point to the source config for live editing
SOURCE_CONFIG="/home/mini2/scripts/utils/process_hdri_config.env"

if [ -f "$SOURCE_CONFIG" ]; then
    echo "Loading LIVE config from: $SOURCE_CONFIG"
    source "$SOURCE_CONFIG"
elif [ -f "$DEPLOYED_CONFIG" ]; then
    echo "Loading DEPLOYED config from: $DEPLOYED_CONFIG"
    source "$DEPLOYED_CONFIG"
else
    echo "Config file not found at: $DEPLOYED_CONFIG or $SOURCE_CONFIG"
fi

# Set defaults if not configured
BALL_SIZE=${BALL_SIZE:-512}
ENVMAP_HEIGHT=${ENVMAP_HEIGHT:-1024}
ALGORITHM=${ALGORITHM:-"turbo_swapping"}
DENOISING_STEPS=${DENOISING_STEPS:-30}
PROMPT=${PROMPT:-"a perfect mirrored reflective chrome ball sphere"}
NEGATIVE_PROMPT=${NEGATIVE_PROMPT:-"matte, diffuse, flat, dull"}

echo "Using BALL_SIZE: $BALL_SIZE"
echo "Using ENVMAP_HEIGHT: $ENVMAP_HEIGHT"

# 3. The Commands
PROCESS_LOGIC="source \$HOME/miniconda3/etc/profile.d/conda.sh && \
               conda activate diffusionlight-turbo && \
               cd \$HOME/DiffusionLight-Turbo && \
               # Prepare directories
               mkdir -p $PROC_DIR/in $PROC_DIR/out && \
               # Copy and rename to 'input_standard'
               cp '$INPUT_PATH' '$PROC_DIR/in/$STAGED_INPUT_NAME' && \
               # Preprocess: Resize to 1024x1024 with black padding
               echo 'from PIL import Image; import sys; p=sys.argv[1]; t=(1024,1024); im=Image.open(p); im.thumbnail(t, getattr(Image, \"Resampling\", Image).LANCZOS); bg=Image.new(\"RGB\", t, (0,0,0)); l=(t[0]-im.width)//2; tp=(t[1]-im.height)//2; bg.paste(im, (l,tp)); bg.save(p)' > $PROC_DIR/preproc.py && \
               python $PROC_DIR/preproc.py '$PROC_DIR/in/$STAGED_INPUT_NAME' && \
               # Run Pipeline on the renamed file
               python inpaint.py --dataset $PROC_DIR/in --output_dir $PROC_DIR/out --ball_size $BALL_SIZE --algorithm '$ALGORITHM' --denoising_step $DENOISING_STEPS --prompt '$PROMPT' --negative_prompt '$NEGATIVE_PROMPT' && \
               python ball2envmap.py --ball_dir $PROC_DIR/out/square --envmap_dir $PROC_DIR/out/envmap --envmap_height $ENVMAP_HEIGHT && \
               python exposure2hdr.py --input_dir $PROC_DIR/out/envmap --output_dir $PROC_DIR/out/hdr && \
               # Restoration logic:
               # Find the output named 'input_standard.hdr' and move it back with original name
               if [ -f '$PROC_DIR/out/hdr/input_standard.exr' ]; then \
                   cp '$PROC_DIR/out/hdr/input_standard.exr' '$ORIGINAL_DIR/${ORIGINAL_BASENAME}.exr' && \
                   echo 'SUCCESS: Created ${ORIGINAL_BASENAME}.exr'; \
               else \
                   echo 'ERROR: Pipeline finished but output file was not found.'; \
                   echo 'Inspecting output directory...'; \
                   ls -R $PROC_DIR/out; \
               fi"

# 4. Launch in Konsole
konsole --hold -e distrobox enter hdri-box -- bash -c "$PROCESS_LOGIC"

# 5. Clean up the temp dir (Uncomment the line below once you confirm it works)
# rm -rf "$PROC_DIR"

notify-send "DiffusionLight" "Process Finished for $ORIGINAL_FILENAME"