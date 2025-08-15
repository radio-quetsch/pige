#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

show_help() {
    cat <<EOF
Purge old recording files from a directory.

USAGE:
  $0 --dir <directory> --max-age <age> [--dry-run]

OPTIONS:
  --dir <directory>   Path to the recordings directory.
  --max-age <age>     Age threshold. Must end with:
                      - Nd  (days)
                      - Nh  (hours)
                      - Nm  (minutes)

  --dry-run           Show files that would be deleted without deleting them.
  -h, --help          Show this help message and exit.

EXAMPLES:
  $0 --dir ./recordings --max-age 7d           # Delete files older than 7 days
  $0 --dir ./recordings --max-age 12h --dry-run # Preview files older than 12h
  $0 --dir ./recordings --max-age 30m          # Delete files older than 30 minutes

NOTES:
  - The script only deletes *.mp3 files.
  - No default max-age: you must explicitly set a suffix.
  - Nonexistent directories will cause an error.
EOF
}

convert_age_to_minutes() {
    local age=$1
    if [[ "$age" =~ ^([0-9]+)d$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 1440 ))
    elif [[ "$age" =~ ^([0-9]+)h$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 60 ))
    elif [[ "$age" =~ ^([0-9]+)m$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        log "ERROR: Invalid age format '$age'. Use Nd (days), Nh (hours), or Nm (minutes)."
        exit 1
    fi
}

PURGE_DIR="${PURGE_DIR:-}"
PURGE_MAX_AGE="${PURGE_MAX_AGE:-}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            PURGE_DIR="$2"
            shift 2
            ;;
        --max-age)
            PURGE_MAX_AGE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$PURGE_DIR" || -z "$PURGE_MAX_AGE" ]]; then
    show_help
    exit 1
fi
if [[ ! -d "$PURGE_DIR" ]]; then
    log "ERROR: Directory not found: $PURGE_DIR"
    exit 1
fi

AGE_MINUTES=$(convert_age_to_minutes "$PURGE_MAX_AGE")

if $DRY_RUN; then
    log "[DRY-RUN] Listing *.mp3 files older than $PURGE_MAX_AGE ($AGE_MINUTES minutes) in '$PURGE_DIR'..."
    find "$PURGE_DIR" -type f -name "*.mp3" -mmin +$AGE_MINUTES -print
    log "[DRY-RUN] No files deleted."
else
    log "Purging *.mp3 files older than $PURGE_MAX_AGE ($AGE_MINUTES minutes) in '$PURGE_DIR'..."
    find "$PURGE_DIR" -type f -name "*.mp3" -mmin +$AGE_MINUTES -print -delete
    log "Purge completed."
fi