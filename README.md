# Radio Recording Script

Records radio streams 24/7 with automatic reconnection and file segmentation.

## Usage

### Docker

```bash
docker build -t pige-recorder .

docker run -d \
  -e STREAM_URL='https://stream.radio.com/live.mp3' \
  -e SEGMENT_DURATION=3600 \
  -v ./recordings:/recordings \
  pige-recorder
```

### Script

```bash
chmod +x recorder.sh
./recorder.sh https://stream.radio.com/live.mp3
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAM_URL` | - | Stream URL (required) |
| `OUTPUT_DIR` | `./recordings` | Output directory |
| `SEGMENT_DURATION` | `3600` | Segment length in seconds |
| `RETRY_DELAY` | `5` | Retry delay in seconds |

## Options

```
--output-dir DIR     Output directory
--segment-time SEC   Segment duration
--retry-delay SEC    Retry delay
--help              Show help
```

## Examples

```bash
# 30min segments
./recorder.sh --segment-time 1800 https://stream.radio.com/live.mp3

# Custom output
./recorder.sh --output-dir /tmp/radio https://stream.radio.com/live.mp3

# Docker with custom user
docker run -u 1000:1000 -v ./recordings:/recordings -e STREAM_URL='...' pige-recorder
```

## Output

Files named: `YYYY-MM-DD_HH-MM-SS.mp3`

## Stop

```bash
# Docker
docker stop container_name

# Script
kill $(cat radio_recording.pid)
```