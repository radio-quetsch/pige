#!/bin/bash

OUTPUT_DIR="${OUTPUT_DIR:-./recordings}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"
HEALTHCHECK_INTERVAL="${HEALTHCHECK_INTERVAL:-60}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Healthcheck: $1"
}

check_recording() {
    local threshold=$(( $(date +%s) - HEALTHCHECK_INTERVAL * 2 ))
    local latest_mtime=0 latest_file="" f mtime
    while IFS= read -r f; do
        mtime=$(stat -c '%Y' "$f" 2>/dev/null) || continue
        if [[ $mtime -gt $latest_mtime ]]; then
            latest_mtime=$mtime
            latest_file=$f
        fi
    done < <(find "$OUTPUT_DIR" -name "*.mp3" -type f 2>/dev/null)

    if [[ $latest_mtime -eq 0 ]]; then
        log "no mp3 found in $OUTPUT_DIR"
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
while true; do
    sleep "$HEALTHCHECK_INTERVAL"
    if check_recording && [[ -n "$HEALTHCHECK_URL" ]]; then
        wget -qO- "$HEALTHCHECK_URL" > /dev/null 2>&1 \
            && log "ping sent" \
            || log "ping failed (wget error)"
    fi
done
