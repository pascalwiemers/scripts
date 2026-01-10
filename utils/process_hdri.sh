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

# 3. The Commands
PROCESS_LOGIC="source \$HOME/miniconda3/etc/profile.d/conda.sh && \
               conda activate diffusionlight-turbo && \
               cd \$HOME/DiffusionLight-Turbo && \
               # Prepare directories
               mkdir -p $PROC_DIR/in $PROC_DIR/out && \
               # Copy and rename to 'input_standard'
               cp '$INPUT_PATH' '$PROC_DIR/in/$STAGED_INPUT_NAME' && \
               # Run Pipeline on the renamed file
               python inpaint.py --dataset $PROC_DIR/in --output_dir $PROC_DIR/out && \
               python ball2envmap.py --ball_dir $PROC_DIR/out/square --envmap_dir $PROC_DIR/out/envmap && \
               python exposure2hdr.py --input_dir $PROC_DIR/out/envmap --output_dir $PROC_DIR/out/hdr && \
               # Restoration logic:
               # Find the output named 'input_standard.hdr' and move it back with original name
               if [ -f '$PROC_DIR/out/hdr/input_standard.hdr' ]; then \
                   cp '$PROC_DIR/out/hdr/input_standard.hdr' '$ORIGINAL_DIR/${ORIGINAL_BASENAME}.hdr' && \
                   echo 'SUCCESS: Created ${ORIGINAL_BASENAME}.hdr'; \
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