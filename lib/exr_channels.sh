#!/usr/bin/env bash
# Shared channel selection for display-ready EXR conversions.
# Print an oiiotool --ch mapping; never invent missing RGB channels.
# Alpha modes: keep (if present), drop, opaque (add A=1 if absent).

exr_channel_args_from_list() {
    local channel_list="$1" input="$2" alpha_mode="${3:-keep}"
    local ch prefix mapping
    local -a channels=() prefixes=()
    local -A present=()
    IFS=, read -r -a channels <<< "${channel_list// /}"
    for ch in "${channels[@]}"; do
        [[ -n "$ch" ]] && present["$ch"]=1
    done
    if [[ -n "${present[R]+x}" && -n "${present[G]+x}" && -n "${present[B]+x}" ]]; then
        prefixes=("")
    else
        for ch in "${channels[@]}"; do
            [[ "$ch" == *.R ]] || continue
            prefix="${ch%R}"
            if [[ -n "${present[${prefix}G]+x}" && -n "${present[${prefix}B]+x}" ]]; then
                prefixes+=("$prefix")
            fi
        done
    fi
    if (( ${#prefixes[@]} != 1 )); then
        echo "Error: $input needs one RGB layer (found ${#prefixes[@]}); split/select a color layer first." >&2
        return 1
    fi
    prefix="${prefixes[0]}"
    mapping="R=${prefix}R,G=${prefix}G,B=${prefix}B"
    case "$alpha_mode" in
        keep|opaque)
            if [[ -n "${present[${prefix}A]+x}" ]]; then
                mapping+=",A=${prefix}A"
            elif [[ "$alpha_mode" == opaque ]]; then
                mapping+=",A=1"
            fi ;;
        drop) ;;
        *) echo "Invalid EXR alpha mode: $alpha_mode" >&2; return 2 ;;
    esac
    printf '%s\n' "$mapping"
}

exr_channel_args() {
    local input="$1" alpha_mode="${2:-keep}" info channel_list
    info=$(oiiotool --info -v "$input") || return 1
    channel_list=$(sed -n 's/.*channel list: *//p' <<< "$info" | head -1)
    exr_channel_args_from_list "$channel_list" "$input" "$alpha_mode"
}

# xargs / GNU Parallel conversion workers run in child Bash processes.
export -f exr_channel_args exr_channel_args_from_list
