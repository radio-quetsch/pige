#!/usr/bin/env bash
set -e

OUTPUT_DIR="${OUTPUT_DIR:-./recordings}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"
HEALTHCHECK_INTERVAL="${HEALTHCHECK_INTERVAL:-60}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Healthcheck: $1"
}

check_recording() {
    local threshold=$(( $(date +%s) - HEALTHCHECK_INTERVAL * 2 ))
    # File names start with the segment start time (%Y-%m-%d_%H-%M-%S), so the
    # last name in byte order is the segment being written. Only that file is
    # stat-ed: on a remote mount (rclone, S3) one stat per file takes seconds
    # once the directory holds hundreds of recordings.
    local LC_ALL=C latest_file latest_mtime
    local -a files
    shopt -s nullglob
    files=("$OUTPUT_DIR"/*.mp3)
    shopt -u nullglob

    if (( ${#files[@]} == 0 )); then
        log "no mp3 found in $OUTPUT_DIR"
        return 1
    fi

    latest_file=${files[-1]}
    if ! latest_mtime=$(stat -c '%Y' "$latest_file" 2>/dev/null); then
        log "FAIL — cannot read ${latest_file##*/}"
        return 1
    fi

    local age=$(( $(date +%s) - latest_mtime ))
    if [[ $latest_mtime -gt $threshold ]]; then
        log "OK — ${latest_file##*/} last written ${age}s ago"
        return 0
    else
        log "FAIL — ${latest_file##*/} last written ${age}s ago (threshold: $(( HEALTHCHECK_INTERVAL * 2 ))s)"
        return 1
    fi
}

# One-shot mode: used by Docker HEALTHCHECK
if [[ "${1:-}" == "--check" ]]; then
    check_recording
    exit $?
fi

# Loop mode: started as background process by recorder.sh
ping_heartbeat() {
    [[ -z "$HEALTHCHECK_URL" ]] && return
    wget -qO- "$HEALTHCHECK_URL" > /dev/null 2>&1 \
        && log "ping sent" \
        || log "ping failed (wget error)"
}

# Send first ping immediately, then every HEALTHCHECK_INTERVAL seconds.
# Elapsed work time is subtracted from sleep so the ping interval stays accurate.
while true; do
    start=$(date +%s)
    check_recording && ping_heartbeat
    elapsed=$(( $(date +%s) - start ))
    remaining=$(( HEALTHCHECK_INTERVAL - elapsed ))
    (( remaining > 0 )) && sleep $remaining
done
