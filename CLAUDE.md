# Notes for Claude / contributors

## EXR → ProRes / MP4 color pipeline

For scripts that turn an ACEScg EXR sequence into a *display-ready* video for review (`exrtoprores444.sh`, `exrtoprores422.sh`, `exrtomp4.sh`, dailies, montages):

- Apply the OCIO display transform directly to the **premultiplied** RGB stored in the EXR.
- **Do not** wrap `--colorconvert` with `--unpremult … --premult`.
- Use `-d uint16` so the PNG intermediate is 16-bit (8-bit causes visible edge banding on semi-transparent pixels).

```
# ProRes 4444 (keep alpha track)
oiiotool "$f" --ch "R,G,B,A" --colorconvert "ACES - ACEScg" "Output - sRGB" -d uint16 -o "$out"

# ProRes 422 / MP4 (no alpha — premult-on-black is implicit)
oiiotool "$f" --ch "R,G,B"   --colorconvert "ACES - ACEScg" "Output - sRGB" -d uint16 -o "$out"
```

**Why:** review happens in Houdini MPlay / Nuke / RV with a manually-set IDT. Those viewers run the OCIO display transform on whatever's in the RGB channels — i.e. the *premultiplied* values stored by the EXR. The "textbook correct" composite-math pipeline (`unpremult → ODT → premult`) sends full-saturation straight RGB through the ACES Output Transform, which boosts saturation/clips at edges, then re-multiplies by tiny alpha — visibly different from what the viewer shows for the source EXR. Matching the viewer's appearance is the goal here, not theoretical compositing correctness.

Skip this rule **only** for outputs intended as compositing source media (round-tripping back into Nuke as scene-linear) — those need the proper unpremult/premult discipline.
