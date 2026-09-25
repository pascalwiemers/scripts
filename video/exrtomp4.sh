#!/usr/bin/env bash
# @kde - Can be deployed to Dolphin/KDE service menu
# exrtomp4.sh – fast EXR → PNG → MP4 converter with optional metadata overlay

# Locate the shared helper in the checkout or the Dolphin deployment.
EXR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/../lib/exr_channels.sh"
[[ -f "$EXR_CHANNELS_LIB" ]] || EXR_CHANNELS_LIB="$EXR_SCRIPT_DIR/lib/exr_channels.sh"
source "$EXR_CHANNELS_LIB" || exit 1
source "$(dirname "$EXR_CHANNELS_LIB")/exr_video.sh" || exit 1

export LC_NUMERIC=C
set -euo pipefail

PARALLEL_JOBS=""
INCLUDE_META=false

echo "🟢  Starting EXR-to-MP4 script …"

# ──────────────────────── 1. Check tools and arguments ─────────────────────
command -v parallel >/dev/null || { echo "GNU parallel not found"; exit 1; }
command -v oiiotool  >/dev/null || { echo "oiiotool not found";  exit 1; }
command -v ffmpeg    >/dev/null || { echo "ffmpeg not found";    exit 1; }
command -v identify  >/dev/null || { echo "identify not found";  exit 1; }

fps_override=""
while (( $# )); do
  case "$1" in
    -fps)
      exr_valid_fps "${2:-}" || { echo "-fps requires a positive number or fraction" >&2; exit 1; }
      fps_override="$2"; shift 2 ;;
    -res)  res="$2"; shift 2 ;;
    -j)    PARALLEL_JOBS="$2"; shift 2 ;;
    -meta) INCLUDE_META=true; shift ;;
    --)    shift; break ;;
    *)     echo "Unknown flag $1"; exit 1 ;;
  esac
done

# ──────────────────────── 2. EXR discovery ─────────────────────────────
shopt -s nullglob
exrs=( *.exr )
(( ${#exrs[@]} )) || { echo "No EXR files found. Exiting."; exit 1; }

first_exr="${exrs[0]}"
fps=$(exr_video_fps "$first_exr" "$fps_override")
res=$(identify -format "%wx%h" "$first_exr")
width=${res%x*}; height=${res#*x}
(( width  & 1 )) && ((width--))
(( height & 1 )) && ((height--))
res="${width}x${height}"

echo "Using FPS=$fps , Resolution=$res"
echo "Metadata overlay: $INCLUDE_META"

# ───────────────────────── 3. Temp workspace ─────────────────────────────
tmpdir=$(mktemp -d -p .)
tmpdir=$(cd "$tmpdir" && pwd)    # absolute path
export tmpdir
echo "Temp dir: $tmpdir"

# ───────────────────────── 4. Optional Metadata ──────────────────────────
if $INCLUDE_META; then
  echo "🔍 Extracting metadata …"
  find . -maxdepth 1 -name '*.exr' | sort -V | \
  parallel ${PARALLEL_JOBS:+-j "$PARALLEL_JOBS"} --halt soon,fail=1 --line-buffer '
    f={}
    info=$(oiiotool -info -v "$f")

    frame=$(awk "/^    frame:/            {print \$2; exit}" <<<"$info")
    fps_tag=$(awk "/^    FramesPerSecond:/  {print \$2; exit}" <<<"$info")
    software=$(grep -oP "^    Software: \"\K.*(?=\")"       <<<"$info")
    host=$(grep -oP "^    HostComputer: \"\K.*(?=\")"     <<<"$info")
    datetime=$(grep -oP "^    DateTime: \"\K.*(?=\")"      <<<"$info")
    mem=$(grep -oP "^    renderMemory_s: \"\K.*(?=\")"     <<<"$info")
    comp=$(grep -oP "^    compression: \"\K.*(?=\")"       <<<"$info")
    colorspace=$(grep -oP "^    oiio:ColorSpace: \"\K.*(?=\")" <<<"$info")
    rt_sec=$(grep -oP "^    renderTime: \K[0-9.]+"         <<<"$info" || echo 0)
    rt_hms=$(grep -oP "^    renderTime_s: \"\K.*(?=\")"    <<<"$info")

    gpu_label=$(grep -oP "\"xpu_device_label\":\"\K[^\"]+"    <<<"$info" | sed -n 1p)
    gpu_pct=$(grep -oP "\"xpu_device_contrib\":\K[0-9.]+" <<<"$info" | sed -n 1p)
    cpu_label=$(grep -oP "\"xpu_device_label\":\"\K[^\"]+"    <<<"$info" | sed -n 2p)
    cpu_pct=$(grep -oP "\"xpu_device_contrib\":\K[0-9.]+" <<<"$info" | sed -n 2p)

    printf "%s|%s|%s|\"%s\"|\"%s\"|\"%s\"|\"%s\"|\"%s\"|\"%s\"|%s|%s|\"%s\"|%s|\"%s\"|%s\n" \
      "$f" "$frame" "$fps_tag" \
      "$software" "$host" "$datetime" \
      "$mem" "$comp" "$colorspace" \
      "$rt_sec" "$rt_hms" \
      "$gpu_label" "$gpu_pct" \
      "$cpu_label" "$cpu_pct"
  ' > "$tmpdir/metadata.txt"

  total_rt_sec=$(awk -F'|' '{sum+=$10} END{printf "%.4f",sum}' "$tmpdir/metadata.txt")
  printf -v total_rt_hms '%02d:%02d:%05.2f' \
          $(awk -v t="$total_rt_sec" 'BEGIN{h=int(t/3600); m=int((t%3600)/60); s=t%60; print h,m,s}')
  echo "⏱  Total render time: $total_rt_hms"
fi

# ──────────────────── 5. EXR → PNG Conversion ───────────────────────────
echo "🎨 Converting EXRs to PNGs …"
if $INCLUDE_META; then
  cat "$tmpdir/metadata.txt" | sort -V | \
  parallel ${PARALLEL_JOBS:+-j "$PARALLEL_JOBS"} --colsep '\|' --halt soon,fail=1 --line-buffer '
    f={1}; frame={2}; fps_tag={3}; software={4}; host={5}; datetime={6};
    mem={7}; comp={8}; colorspace={9}; rth={11};
    gpu_label={12}; gpu_pct={13}; cpu_label={14}; cpu_pct={15};

    fbase=${f#./}; fb=${fbase%.exr}

    CH_ARGS=$(exr_channel_args "$f" drop) || exit 1
    oiiotool "$f" --ch "$CH_ARGS" \
      --colorconvert "ACES - ACEScg" "Output - sRGB" \
      --text:x=40:y=40:size=28 "Frame: ${frame:-N/A}   FPS: ${fps_tag:-'"$fps"'}" \
      --text:x=40:y=80:size=28  "RenderTime: ${rth:-N/A}" \
      --text:x=40:y=120:size=28 "Software: ${software:-Unknown}" \
      --text:x=40:y=160:size=28 "Host: ${host:-Unknown}" \
      --text:x=40:y=200:size=28 "Mem: ${mem:-?}   Comp: ${comp:-?}" \
      --text:x=40:y=240:size=28 "ColorSpace: ${colorspace:-?}" \
      --text:x=40:y=280:size=28 "Date: ${datetime:-?}" \
      --text:x=40:y=320:size=28 "GPU: ${gpu_label:-N/A} (${gpu_pct:-0}%)" \
      --text:x=40:y=360:size=28 "CPU: ${cpu_label:-N/A} (${cpu_pct:-0}%)" \
      --text:x=40:y=400:size=28 "TotalRender: '"$total_rt_hms"'" \
      -d uint16 -o "$tmpdir/${fb}_converted.png"
  '
else
  find . -maxdepth 1 -name '*.exr' | sort -V | \
  parallel ${PARALLEL_JOBS:+-j "$PARALLEL_JOBS"} --halt soon,fail=1 --line-buffer '
    f={}
    fbase=${f#./}; fb=${fbase%.exr}
    CH_ARGS=$(exr_channel_args "$f" drop) || exit 1
    oiiotool "$f" --ch "$CH_ARGS" --colorconvert "ACES - ACEScg" "Output - sRGB" \
      -d uint16 -o "$tmpdir/${fb}_converted.png"
  '
fi

# ──────────────────────── 6. Assemble MP4 ────────────────────────────────
echo "📜  Preparing image sequence for FFmpeg …"
exr_video_link_frames "$tmpdir"

out_base=$(basename "$first_exr" .exr | sed -E 's/\.[0-9]+$//')
out_mp4="${out_base}.mp4"

echo "🎞  Encoding MP4 → $out_mp4"
# Read numbered PNGs directly for parallel decoding and exact frame timing.
ffmpeg -y -loglevel error -framerate "$fps" -start_number 0 -i "$tmpdir/frames/%08d.png" \
       -c:v libx264 -pix_fmt yuv420p -fps_mode passthrough -s "$res" \
       "$tmpdir/$out_mp4"

# ───────────────────────── 7. Cleanup ────────────────────────────────────
mv "$tmpdir/$out_mp4" .
rm -rf "$tmpdir"

echo "✅  Done – output is $out_mp4"
