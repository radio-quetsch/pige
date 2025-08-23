#!/bin/bash
set -e

# ===========================
# Configuration (env or args)
# ===========================
STREAM_URL="${STREAM_URL:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./recordings}"
SEGMENT_DURATION="${SEGMENT_DURATION:-3600}" # in seconds
LOG_FILE="${LOG_FILE:-/tmp/radio_recording.log}"
RETRY_DELAY="${RETRY_DELAY:-5}" # seconds

# ===========================
# Help function
# ===========================
show_help() {
    cat << EOF
24/7 Radio Recording Script with FFmpeg

USAGE:
    $0 [OPTIONS] <STREAM_URL>
    $0 --help

ARGUMENTS:
    STREAM_URL           Audio stream URL to record

OPTIONS:
    --output-dir DIR     Output directory (default: ./recordings)
    --segment-time SEC   Segment duration in seconds (default: 3600)
    --log-file FILE      Log file (default: ./radio_recording.log)
    --retry-delay SEC    Delay between retries in seconds (default: 5)
    --help               Show this help

ENV VARIABLES:
    STREAM_URL
    OUTPUT_DIR
    SEGMENT_DURATION
    LOG_FILE
    RETRY_DELAY

EXAMPLES:
    $0 http://stream.radio.com/live.mp3
    $0 --output-dir /tmp/recordings --segment-time 1800 http://stream.radio.com/live.mp3
EOF
}

# ===========================
# Argument parsing
# ===========================
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --segment-time)
            SEGMENT_DURATION="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --retry-delay)
            RETRY_DELAY="$2"
            shift 2
            ;;
        --*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ -z "$STREAM_URL" ]]; then
                STREAM_URL="$1"
            else
                echo "Too many arguments. Stream URL already defined: $STREAM_URL"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$STREAM_URL" ]]; then
    echo "Error: Stream URL is required."
    show_help
    exit 1
fi

# ===========================
# Logging
# ===========================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ===========================
# Cleanup on exit
# ===========================
cleanup() {
    log "Stopping recording..."
    log "Script stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM SIGQUIT

# ===========================
# Prepare output
# ===========================
mkdir -p "$OUTPUT_DIR"
log "Starting radio recording..."
log "Stream URL: $STREAM_URL"
log "Output dir: $OUTPUT_DIR"
log "Segment duration: ${SEGMENT_DURATION}s"
log "Retry delay: ${RETRY_DELAY}s"

# ===========================
# Recording loop
# ===========================
while true; do
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    output_file="${OUTPUT_DIR}/${timestamp}.mp3"
    
    log "Recording to: $output_file"

    ffmpeg -y \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 30 \
        -reconnect_at_eof 1 \
        -timeout 30000000 \
        -i "$STREAM_URL" \
        -strftime 1 \
        -f segment \
        -segment_time "$SEGMENT_DURATION" \
        -reset_timestamps 1 \
        -write_empty_segments 1 \
        -avoid_negative_ts make_zero \
        -c:a copy \
        "${OUTPUT_DIR}/%Y-%m-%d_%H-%M-%S.mp3"

    ffmpeg_exit=$?
    if [[ $ffmpeg_exit -eq 0 ]]; then
        log "Segment finished successfully: $output_file"
    elif [[ $ffmpeg_exit -eq 130 ]]; then
        log "Interrupted by user"
        cleanup
    else
        log "FFmpeg exited with code $ffmpeg_exit, retrying in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"
    fi
done
