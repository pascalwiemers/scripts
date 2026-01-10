#!/bin/bash
# @kde

INPUT_IMAGE=$(realpath "$1")
ORIGINAL_DIR=$(dirname "$INPUT_IMAGE")
FILENAME=$(basename "$INPUT_IMAGE")
BASENAME="${FILENAME%.*}"

# Unique ID to allow simultaneous processing of different images
TEMP_ID=$(date +%s)
PROC_DIR="/tmp/hdri_proc_$TEMP_ID"

# Commands sent to the Ubuntu box
# Note: $HOME is shared between Rocky and the Container
PROCESS_LOGIC="source \$HOME/miniconda3/etc/profile.d/conda.sh && \
               conda activate diffusionlight-turbo && \
               cd \$HOME/DiffusionLight-Turbo && \
               mkdir -p $PROC_DIR/in $PROC_DIR/out && \
               cp '$INPUT_IMAGE' $PROC_DIR/in/ && \
               python inpaint.py --dataset $PROC_DIR/in --output_dir $PROC_DIR/out && \
               python ball2envmap.py --ball_dir $PROC_DIR/out/square --envmap_dir $PROC_DIR/out/envmap && \
               python exposure2hdr.py --input_dir $PROC_DIR/out/envmap --output_dir $PROC_DIR/out/hdr && \
               cp $PROC_DIR/out/hdr/${BASENAME}.hdr '$ORIGINAL_DIR/' && \
               rm -rf $PROC_DIR"

# Launch in a terminal so you can monitor progress
konsole --hold -e distrobox enter hdri-box -- bash -c "$PROCESS_LOGIC"

notify-send "DiffusionLight" "Generated ${BASENAME}.hdr in $ORIGINAL_DIR"
