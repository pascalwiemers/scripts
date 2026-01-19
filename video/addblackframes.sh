#!/bin/bash
# @kde - Can be deployed to Dolphin/KDE service menu
# addblackframes.sh - Add black frames at the start and/or end of video files

set -euo pipefail

# Default values
START_FRAMES=""  # Empty means use default (1 second)
END_FRAMES=""    # Empty means use default (1 second)
START_SET=false  # Track if -start was explicitly set
END_SET=false    # Track if -end was explicitly set
ADD_START=true
ADD_END=true

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS] [VIDEO_FILE...]"
    echo ""
    echo "Options:"
    echo "  -start N     Number of black frames to add at the start (default: 1 second based on video FPS)"
    echo "  -end N       Number of black frames to add at the end (default: 1 second based on video FPS)"
    echo "  -nostart     Don't add frames at the start"
    echo "  -noend       Don't add frames at the end"
    echo "  -h, --help   Show this help message"
    echo ""
    echo "If no video files are provided, processes all video files in the current directory."
    echo ""
    echo "Examples:"
    echo "  $0                           # Add 1 second at start and end to all videos"
    echo "  $0 -start 5 -end 3 video.mp4 # Add 5 frames at start, 3 frames at end"
    echo "  $0 -nostart -end 10          # Only add 10 frames at end to all videos"
}

# Parse command line arguments
FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        -start)
            START_FRAMES="$2"
            START_SET=true
            if ! [[ "$START_FRAMES" =~ ^[0-9]+$ ]] || [ "$START_FRAMES" -lt 0 ]; then
                echo "Error: -start requires a non-negative integer"
                exit 1
            fi
            shift 2
            ;;
        -end)
            END_FRAMES="$2"
            END_SET=true
            if ! [[ "$END_FRAMES" =~ ^[0-9]+$ ]] || [ "$END_FRAMES" -lt 0 ]; then
                echo "Error: -end requires a non-negative integer"
                exit 1
            fi
            shift 2
            ;;
        -nostart)
            ADD_START=false
            shift
            ;;
        -noend)
            ADD_END=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            exit 1
            ;;
        *)
            if [ -f "$1" ]; then
                FILES+=("$1")
            else
                echo "Warning: File '$1' not found, skipping"
            fi
            shift
            ;;
    esac
done

# If no files specified, find all video files in current directory
if [ ${#FILES[@]} -eq 0 ]; then
    shopt -s nullglob
    # Common video extensions
    FILES=(*.mp4 *.mov *.avi *.mkv *.webm *.flv *.m4v *.3gp *.wmv *.mpg *.mpeg *.ts *.m2ts)
    if [ ${#FILES[@]} -eq 0 ]; then
        echo "Error: No video files found in current directory"
        exit 1
    fi
fi

# Check if ffmpeg is available
command -v ffmpeg >/dev/null 2>&1 || { echo "Error: ffmpeg not found"; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "Error: ffprobe not found"; exit 1; }

# Function to process a video file
process_video() {
    local input_file="$1"
    local filename=$(basename -- "$input_file")
    local extension="${filename##*.}"
    local filename_without_ext="${filename%.*}"
    local output="${filename_without_ext}_blackframes.${extension}"

    echo "Processing: $input_file"

    # Get video properties
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nokey=1:noprint_wrappers=1 "$input_file")
    local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nokey=1:noprint_wrappers=1 "$input_file")
    local fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nokey=1:noprint_wrappers=1 "$input_file" | awk -F '/' '{ if ($2 != 0) print $1/$2; else print 25 }')
    local pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nokey=1:noprint_wrappers=1 "$input_file")
    local duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nokey=1:noprint_wrappers=1 "$input_file")
    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 "$input_file")
    
    # Detect if video has audio
    local has_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 "$input_file" 2>/dev/null || echo "")

    # Calculate frames to add (default: 1 second = fps frames)
    local start_frames_to_add=0
    local end_frames_to_add=0
    
    if [ "$ADD_START" = true ]; then
        if [ "$START_SET" = true ] && [ -n "$START_FRAMES" ]; then
            # User explicitly set frames
            start_frames_to_add=$START_FRAMES
        else
            # Default: 1 second (calculate from fps)
            start_frames_to_add=$(awk "BEGIN {printf \"%.0f\", $fps}")
        fi
    fi
    
    if [ "$ADD_END" = true ]; then
        if [ "$END_SET" = true ] && [ -n "$END_FRAMES" ]; then
            # User explicitly set frames
            end_frames_to_add=$END_FRAMES
        else
            # Default: 1 second (calculate from fps)
            end_frames_to_add=$(awk "BEGIN {printf \"%.0f\", $fps}")
        fi
    fi

    # Calculate duration for black frames (in seconds)
    local start_duration=0
    local end_duration=0
    if [ "$start_frames_to_add" -gt 0 ]; then
        start_duration=$(awk "BEGIN {printf \"%.6f\", $start_frames_to_add / $fps}")
    fi
    if [ "$end_frames_to_add" -gt 0 ]; then
        end_duration=$(awk "BEGIN {printf \"%.6f\", $end_frames_to_add / $fps}")
    fi

    # Skip if no frames to add
    if [ "$ADD_START" = false ] && [ "$ADD_END" = false ]; then
        echo "  Skipping: No frames to add"
        return
    fi
    if [ "$start_duration" = "0" ] && [ "$end_duration" = "0" ]; then
        echo "  Skipping: Frame count is 0"
        return
    fi

    # Build ffmpeg command using filter_complex
    echo "  Concatenating..."
    local ffmpeg_inputs=()
    local filter_parts=()
    local stream_index=0

    # Determine video codec for output (use high quality settings)
    local output_codec="libx264"
    local codec_opts=()
    case "$codec" in
        h264|libx264)
            output_codec="libx264"
            codec_opts=(-preset medium -crf 18)
            ;;
        hevc|h265|libx265)
            output_codec="libx265"
            codec_opts=(-preset medium -crf 18)
            ;;
        vp9|libvpx-vp9)
            output_codec="libvpx-vp9"
            codec_opts=(-crf 30 -b:v 0)
            ;;
        *)
            # Default to h264 with high quality
            output_codec="libx264"
            codec_opts=(-preset medium -crf 18)
            ;;
    esac

    # Build filter_complex for video concatenation
    # Add start black frames if needed
    if [ "$ADD_START" = true ] && [ "$start_frames_to_add" -gt 0 ]; then
        if [ "$START_SET" = true ]; then
            echo "  Adding $start_frames_to_add black frame(s) (${start_duration}s) at start..."
        else
            echo "  Adding 1 second ($start_frames_to_add frames) of black at start..."
        fi
        ffmpeg_inputs+=(-f lavfi -i "color=c=black:s=${width}x${height}:d=$start_duration:r=$fps")
        filter_parts+=("[${stream_index}:v]")
        stream_index=$((stream_index + 1))
    fi

    # Add original video
    ffmpeg_inputs+=(-i "$input_file")
    filter_parts+=("[${stream_index}:v]")
    stream_index=$((stream_index + 1))

    # Add end black frames if needed
    if [ "$ADD_END" = true ] && [ "$end_frames_to_add" -gt 0 ]; then
        if [ "$END_SET" = true ]; then
            echo "  Adding $end_frames_to_add black frame(s) (${end_duration}s) at end..."
        else
            echo "  Adding 1 second ($end_frames_to_add frames) of black at end..."
        fi
        ffmpeg_inputs+=(-f lavfi -i "color=c=black:s=${width}x${height}:d=$end_duration:r=$fps")
        filter_parts+=("[${stream_index}:v]")
        stream_index=$((stream_index + 1))
    fi

    # Build concat filter
    local num_inputs=${#filter_parts[@]}
    local filter_complex="${filter_parts[*]}concat=n=${num_inputs}:v=1[outv]"

    # Build complete filter_complex
    # For audio, we'll map it directly from the input video stream

    # Build final ffmpeg command
    local ffmpeg_args=("${ffmpeg_inputs[@]}")
    ffmpeg_args+=(-filter_complex "$filter_complex")
    ffmpeg_args+=(-map "[outv]")
    
    if [ -n "$has_audio" ]; then
        # Map audio from the original video input (index depends on whether we have start black)
        local audio_input_idx=$([ "$ADD_START" = true ] && [ "$start_frames_to_add" -gt 0 ] && echo 1 || echo 0)
        ffmpeg_args+=(-map "${audio_input_idx}:a")
        ffmpeg_args+=(-c:a copy)
    else
        ffmpeg_args+=(-an)
    fi

    ffmpeg_args+=(-c:v "$output_codec" "${codec_opts[@]}")
    ffmpeg_args+=(-pix_fmt yuv420p)
    ffmpeg_args+=(-y "$output")

    # Run ffmpeg
    ffmpeg "${ffmpeg_args[@]}" >/dev/null 2>&1 || {
        echo "  Error processing $input_file"
        return
    }

    echo "  ✅ Created: $output"
}

# Process all files
for file in "${FILES[@]}"; do
    process_video "$file"
done

echo "Done!"

