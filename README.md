# Radio Recording Script

Records radio streams 24/7 with automatic reconnection and file segmentation.

## Images

| Image | Description |
|-------|-------------|
| `pige-recorder` | Records a stream continuously, splits into hourly files |
| `pige-purger` | Deletes recordings older than a configured number of days |

```bash
# Build
docker build --network host --target recorder -t pige-recorder .
docker build --network host --target purger -t pige-purger .
```

## Usage

### Docker

```bash
docker run -d \
  -e STREAM_URL='https://stream.radio.com/live.mp3' \
  -e SEGMENT_DURATION=3600 \
  -v ./recordings:/recordings \
  pige-recorder
```

### Script

```bash
./recorder.sh https://stream.radio.com/live.mp3
./recorder.sh --output-dir /tmp/radio --segment-time 1800 https://stream.radio.com/live.mp3
```

## Configuration

### Recorder

| Variable | Arg | Default | Description |
|----------|-----|---------|-------------|
| `STREAM_URL` | positional | — | Stream URL (required) |
| `OUTPUT_DIR` | `--output-dir` | `./recordings` | Output directory |
| `SEGMENT_DURATION` | `--segment-time` | `3600` | Segment length in seconds |
| `LOG_FILE` | `--log-file` | — | Log file path (stdout only if not set) |
| `RETRY_DELAY` | `--retry-delay` | `5` | Retry delay on error (seconds) |
| `FFMPEG_STATS` | `--ffmpeg-stats` | `false` | Enable ffmpeg progress output |
| `HEALTHCHECK_URL` | `--healthcheck-url` | — | URL to ping (Uptime Kuma, healthchecks.io…) |
| `HEALTHCHECK_INTERVAL` | `--healthcheck-interval` | `60` | Ping interval in seconds |

### Purger

| Variable | Default | Description |
|----------|---------|-------------|
| `PURGE_SCHEDULE` | `0 */6 * * *` | Cron schedule |

## Healthcheck

The recorder ships with a `healthcheck.sh` that verifies the most recently written `.mp3` file is recent.

It runs in two modes:

- **Loop** — started automatically by `recorder.sh`, pings `HEALTHCHECK_URL` every `HEALTHCHECK_INTERVAL` seconds if recording is healthy
- **One-shot** (`--check`) — used by Docker's `HEALTHCHECK`, exits 0 (healthy) or 1 (unhealthy)

```bash
# Check Docker container health
docker inspect <container> --format='{{.State.Health.Status}}'

# Uptime Kuma (push monitor)
HEALTHCHECK_URL='https://uptime.kuma.pet/api/push/<token>?status=up&msg=OK'

# healthchecks.io
HEALTHCHECK_URL='https://hc-ping.com/<uuid>'
```

A ping is only sent when a `.mp3` file has been written within the last `HEALTHCHECK_INTERVAL * 2` seconds. If ffmpeg crashes or the stream dies, pings stop and the monitor detects the outage after its own timeout.

## Output

Files named: `YYYY-MM-DD_HH-MM-SS.mp3`

## Stop

```bash
# Docker
docker stop <container>

# Script
Ctrl+C  # healthcheck process is also stopped automatically
```
