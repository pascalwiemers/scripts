# Linux Scripts

A collection of small scripts used to speed up everyday CG/VFX work on Linux. They cover video conversion, EXR sequence processing, file management and various utility tasks.

## Dependencies

### Quick Start

Run the installer on Rocky Linux / RHEL / AlmaLinux:

```bash
bash install/setup_deps.sh
```

It covers repositories, packages, and gives you an interactive choice for the OIIO/OCIO stack (see below).

### Required

| Package | Used by | Install |
|---------|---------|---------|
| [ffmpeg](https://www.ffmpeg.org/) | All video scripts | `dnf install ffmpeg` (RPM Fusion) |
| [ImageMagick](https://imagemagick.org/) | Image conversion, montages | `dnf install ImageMagick` |
| [GNU parallel](https://www.gnu.org/software/parallel/) | EXR batch processing | `dnf install parallel` |
| [poppler-utils](https://poppler.freedesktop.org/) | `pdftojpg.sh` | `dnf install poppler-utils` |
| python3 + tkinter | batchexrtomp4.py | `dnf install python3 python3-tkinter` |

### Required for EXR / Color Workflows

The EXR scripts (`exrtomp4.sh`, `exrtoprores*.sh`, `exrtojpg.sh`, `exrtotiff.sh`, `exrmerge.sh`, montages) need **oiiotool** with a working **OCIO** (ACES 1.2) config. There are three ways to get this on Rocky:

| Strategy | Pros | Cons |
|----------|------|------|
| **System packages** (`dnf install OpenImageIO-utils`) | Simplest, no extra deps | Older version (2.4.x), may need manual OCIO setup |
| **Distrobox container** (Ubuntu `oiio-box`) | Newer oiiotool, isolated, no commercial dependency | Requires distrobox + podman |
| **Houdini** (`hoiiotool` wrapper) | Newest version (2.5.x), self-contained OCIO | Requires Houdini install ($$$) |

`install/setup_deps.sh` lets you pick interactively. To set up just the distrobox container independently:

```bash
bash install/setup_oiio_container.sh
```

All three strategies ensure `OCIO` is set in `~/.bashrc` and `~/bin/oiiotool` is on your PATH.

### Optional

| Package | Used by | Install |
|---------|---------|---------|
| mpv | Grid playback (`grid_play.sh`) | `dnf install mpv` |
| dolphin, kdialog, konsole | KDE desktop integration scripts | `dnf install dolphin kdialog konsole` |
| libnotify | Desktop notifications | `dnf install libnotify` |
| xclip | Clipboard scripts | `dnf install xclip` |
| sox | Audio processing | `dnf install sox` |
| tmux, btop, nvtop | Monitor scripts (`monitor.sh`) | `dnf install tmux btop nvtop` |
| rsync | `syncblender.sh` | `dnf install rsync` |
| inotify-tools | Watch scripts | `dnf install inotify-tools` |
| unrtf | `rft_to_txt.sh` | `dnf install unrtf` |
| jq | JSON processing | `dnf install jq` |
| distrobox | `process_hdri.sh`, `process_pano.sh`, oiio-box | `dnf install distrobox` |
| Whisper | `videototxt.sh`, `transcribe.sh` | pip install (separate) |

## Script Overview

Scripts are grouped roughly by purpose. Most of them are self-contained shell utilities and can be run from any directory once the repo is on your `PATH`.

### Video Conversion & Encoding

- **aratio.sh** – crop a video into 1:1, 4:5, 16:9 and 9:16 versions.
- **aratio_high.sh** – high quality variant of `aratio.sh`.
- **exrtomp4.sh** – convert an ACEScg EXR sequence to an sRGB MP4.  
  Example: `exrtomp4 -fps 30 -res 1080x1080`
- **exrtoprores422.sh** – convert an EXR sequence to ProRes 422.
- **exrtoprores444.sh** – convert an EXR sequence to ProRes 444.
- **movtoexr.sh** – turn a video file into a DWAB-compressed EXR sequence.
- **mkv_mov.sh** – convert MKV into a ProRes 422 MOV file.
- **mp4.sh / mp4hq.sh** – convert videos to MP4 (standard / high quality).
- **smp4.sh** – create a smaller MP4 with `_small` suffix in the same folder.
- **prores422hq.sh** – encode videos as ProRes 422 HQ.
- **prores444.sh** – encode videos as ProRes 444.
- **webmp4.sh / webmp4_smaller.sh** – create web-optimized MP4s.
- **pngtomp4.sh** – stitch PNG sequence into MP4.
- **mp4topng.sh** – extract PNG frames from video.
- **mp4towav.sh** – extract WAV audio from video.
- **videotomp3.sh** – convert a video to MP3 audio.
- **videotojpg.sh / videotopng.sh** – convert video to image sequence.
- **videototxt.sh** – convert video to MP3 and transcribe using Whisper.

### Sequence and Image Tools

- **exrarchive.sh** – scan subfolders for EXR sequences and convert to MP4.
- **exrmerge.sh** – merge `_l.exr` and `_r.exr` images into a single file.
- **exrtojpg.sh** – convert a single EXR to JPG.
- **exrtotiff.sh** – convert a single EXR to TIFF.
- **exrtotiff_ProPhotoRGB.sh** – make a ProPhoto RGB TIFF from EXR.
- **pdftojpg.sh** – convert PDF pages to 300 DPI JPG images (output to `pdftojpg/` subfolder).
- **extractstills.sh / autocut.sh** – grab stills based on sensitivity.
- **extractallstills.sh** – run `extractstills.sh` across folders.
- **pngtomp4.sh** – convert PNG sequence to MP4.
- **thumbnail.sh / .thumbnail.sh** – extract first or custom thumbnails.
- **montage.sh / montage4.sh / montage6.sh** – build mosaics from EXR frames.

### Video Editing Utilities

- **joinvideo.sh / videomerge.sh** – concatenate multiple videos.
- **mergeprores.sh / mergeprores2.sh** – merge ProRes left/right into one.
- **grid3.sh / grid3_backup.sh** – make 3×3 grid videos from MP4s.
- **grid_play.sh** – play multiple videos in a grid with `mpv`.
- **trim.sh** – trim frames off start/end of a video.
- **addblackframes.sh** – add black frames at the start and/or end of videos.  
  By default adds 1 second of black at each end (based on video FPS).  
  Options: `-start N`, `-end N`, `-nostart`, `-noend`.  
  Example: `addblackframes.sh -start 5 -end 3 video.mp4`
- **record.sh** – GPU desktop + webcam recorder with preview.

### HDRI Tools

- **process_hdri.sh** – generate HDRIs from a single image using DiffusionLight-Turbo (runs in Distrobox).
- **hdri_diffusionLight.sh** – setup script for the `process_hdri.sh` environment (creates `hdri-box` container).
- **hdri.sh** – legacy wrapper for the original DiffusionLight pipeline.

### GIFs and Watchers

- **gif.sh / gif_small.sh** – create GIFs (normal/small).
- **watch_convert_to_gif.sh** – auto-convert new videos to GIF.
- **watch_move_videos.sh** – move incoming videos to subfolders.

### Audio and Transcription

- **applyaudio.sh** – attach a given audio track to multiple videos.
- **noaudio.sh** – strip audio from video files.
- **mp4towav.sh / videotomp3.sh** – extract audio tracks.
- **transcribe.sh** – transcribe audio via Whisper.
- **formatjson.sh / formattxt.sh** – format Whisper output.
- **rft_to_txt.sh** – convert RTF to plain text.

### Desktop & System Utilities

- **date.sh** – create folder named with today’s date.
- **project_folder.sh** – create standard project folder layout.
- **folder.sh** – build folders from tree-like indented text.
- **clean.sh** – recursively delete `tmp*` folders.
- **htmlpreview.sh** – generate HTML gallery for image sequences.
- **open_clipboard.sh** – open clipboard path/image in tool.
- **chatid.sh** – get Telegram bot’s last chat ID.
- **monitor.sh / monitor2.sh / mm.sh** – launch `tmux` session with `nvtop` + `btm`.
- **obs_copy.sh** – auto-copy new OBS recordings to dated folders.
- **syncblender.sh** – sync Blender configs via `rsync`.
- **set_wacom.sh / wacom1.sh / wacom2.sh / wacom3.sh** – map Wacom tablet to monitor.
- **sine.sh** – toggle test tone signal.
- **deadline_env_mint.sh** – start Deadline with custom env vars.

### Desktop Integration

- **create_desktop.sh** – generate `.desktop` service menu entries.
- **deploy_desktop_files.sh** – install entries from `desktop_files/`.
- **desktop_files/** – example KDE/Dolphin integration files.

### Python GUI

- **batchexrtomp4.py** – Tkinter app to batch convert EXR sequences.

## Usage

Place this repository somewhere in your `PATH` or call the scripts with their full path. Most scripts support command-line flags; read them directly for available options.
