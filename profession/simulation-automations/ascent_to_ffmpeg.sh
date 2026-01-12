#!/usr/bin/env bash
###############################################################################
# ascent_to_video.sh  —  Source this to obtain the ascent_to_video() function
# (formerly make_video)
#
# Synopsis
#   ascent_to_video  <filebase>  <length-seconds>  [framerate]
###############################################################################

ascent_to_video() {
    RED=$'\e[1;31m'; GREEN=$'\e[1;32m'; YELLOW=$'\e[1;33m'; CYAN=$'\e[36m'; NC=$'\e[0m'

    # ---- options ----
    local nointerp=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --nointerpolate)
                nointerp=1
                shift
                ;;
            -h|--help)
                printf "${YELLOW}Usage:${NC} ascent_to_video [--nointerpolate] <filebase> <length-seconds> [framerate]\n" >&2
                return 0
                ;;
            *)
                break
                ;;
        esac
    done

    local filebase=$1        # may be relative or absolute
    local length=$2
    local framerate=${3:-50}

    # ── basic validation ─────────────────────────────────────────────────────
    if [[ -z ${filebase:-} || -z ${length:-} ]]; then
        printf "${YELLOW}Usage:${NC} ascent_to_video [--nointerpolate] <filebase> <length-seconds> [framerate]\n" >&2
        return 1
    fi
    [[ $length    =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf "${RED}Error:${NC} length must be numeric\n" >&2;    return 1; }
    [[ $framerate =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf "${RED}Error:${NC} framerate must be numeric\n" >&2; return 1; }

    # ── resolve paths ────────────────────────────────────────────────────────
    local dir base pattern frames num_frames factor outfile
    dir=$(dirname "$filebase")
    base=$(basename "$filebase")
    pattern="${dir}/${base}-[0-9]*.png"

    shopt -s nullglob
    frames=( $pattern )
    shopt -u nullglob
    num_frames=${#frames[@]}
    if (( num_frames == 0 )); then
        printf "${RED}Error:${NC} no files match pattern '%s'\n" "$pattern" >&2
        return 1
    fi

    # ── compute playback factor ──────────────────────────────────────────────
    factor=$(awk "BEGIN { printf \"%.6f\", $length * $framerate / $num_frames }")
    outfile="${dir}/${base}.mp4"

    # ── ffmpeg path (custom or system) ───────────────────────────────────────
    local ffmpeg_bin="/mnt/share/sambit98/.local/downloads/ffmpeg/ffmpeg-7.0.2-amd64-static/ffmpeg"
    [[ -x $ffmpeg_bin ]] || ffmpeg_bin=ffmpeg

    # ── build filter chain ───────────────────────────────────────────────────
    local vf
    if (( nointerp )); then
        vf="setpts=${factor}*PTS"
    else
        vf="setpts=${factor}*PTS,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:search_param=200"
    fi

    printf "${CYAN}Frames            : %d${NC}\n" "$num_frames"
    printf "${CYAN}Input FPS         : %s${NC}\n" "$framerate"
    printf "${CYAN}Target length     : %ss${NC}\n" "$length"
    printf "${CYAN}Playback factor   : %s${NC}\n" "$factor"
    printf "${CYAN}Interpolation     : %s${NC}\n" "$([[ $nointerp -eq 1 ]] && echo 'OFF' || echo 'ON')"
    printf "${CYAN}Output file       : %s${NC}\n\n" "$outfile"

    "$ffmpeg_bin" -y \
        -pattern_type glob -framerate "$framerate" \
        -i "$pattern" \
        -vf "$vf" \
        -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
        "$outfile" || return 1

    printf "${GREEN}Done – created:${NC} %s\n" "$outfile"
}


# Optional: export the function for subshells
# export -f ascent_to_video
