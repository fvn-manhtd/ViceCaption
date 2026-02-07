#!/usr/bin/env bash
set -euo pipefail

PROCESS_NAME="VibeCaption"
PID=""
MINUTES=60
INTERVAL=1
OUTPUT=""

usage() {
  cat <<USAGE
Usage:
  $0 [--process-name NAME] [--pid PID] [--minutes N] [--interval SECONDS] [--output FILE]

Examples:
  $0 --process-name VibeCaption --minutes 60 --output Docs/perf-reports/normal-mode.csv
  $0 --pid 12345 --minutes 30 --interval 2 --output /tmp/vibecaption.csv
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --process-name)
      PROCESS_NAME="$2"; shift 2 ;;
    --pid)
      PID="$2"; shift 2 ;;
    --minutes)
      MINUTES="$2"; shift 2 ;;
    --interval)
      INTERVAL="$2"; shift 2 ;;
    --output)
      OUTPUT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$PID" ]]; then
  PID=$(pgrep -x "$PROCESS_NAME" | head -n 1 || true)
fi

if [[ -z "$PID" ]]; then
  echo "Could not find running process. Start the app first, then rerun." >&2
  exit 1
fi

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]] || ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
  echo "--minutes and --interval must be integers." >&2
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  TS=$(date +"%Y%m%d-%H%M%S")
  OUTPUT="/tmp/vibecaption-performance-${TS}.csv"
fi

mkdir -p "$(dirname "$OUTPUT")"

echo "Profiling PID $PID for ${MINUTES} minute(s), sample interval ${INTERVAL}s"
echo "timestamp,cpu_percent,rss_kb" > "$OUTPUT"

samples=$(( MINUTES * 60 / INTERVAL ))
if (( samples <= 0 )); then
  echo "Computed sample count is zero. Increase duration or lower interval." >&2
  exit 1
fi

sum_cpu=0
min_cpu=1000000
max_cpu=0
sum_rss=0
min_rss=1000000000000
max_rss=0
valid_samples=0

for ((i=0; i<samples; i++)); do
  if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Process $PID exited early at sample $i." >&2
    break
  fi

  line=$(ps -p "$PID" -o %cpu=,rss= | awk '{print $1","$2}')
  cpu=$(echo "$line" | cut -d, -f1 | tr -d ' ')
  rss=$(echo "$line" | cut -d, -f2 | tr -d ' ')
  ts=$(date +"%Y-%m-%dT%H:%M:%S")

  echo "${ts},${cpu},${rss}" >> "$OUTPUT"

  cpu_int=$(awk -v c="$cpu" 'BEGIN { printf("%.0f", c*100) }')
  rss_int=${rss:-0}

  (( sum_cpu += cpu_int ))
  (( sum_rss += rss_int ))
  (( cpu_int < min_cpu )) && min_cpu=$cpu_int
  (( cpu_int > max_cpu )) && max_cpu=$cpu_int
  (( rss_int < min_rss )) && min_rss=$rss_int
  (( rss_int > max_rss )) && max_rss=$rss_int
  (( valid_samples += 1 ))

  sleep "$INTERVAL"
done

if (( valid_samples == 0 )); then
  echo "No samples collected." >&2
  exit 1
fi

avg_cpu=$(awk -v s="$sum_cpu" -v n="$valid_samples" 'BEGIN { printf("%.2f", (s/n)/100.0) }')
min_cpu_fmt=$(awk -v v="$min_cpu" 'BEGIN { printf("%.2f", v/100.0) }')
max_cpu_fmt=$(awk -v v="$max_cpu" 'BEGIN { printf("%.2f", v/100.0) }')

avg_rss_mb=$(awk -v s="$sum_rss" -v n="$valid_samples" 'BEGIN { printf("%.2f", (s/n)/1024.0) }')
min_rss_mb=$(awk -v v="$min_rss" 'BEGIN { printf("%.2f", v/1024.0) }')
max_rss_mb=$(awk -v v="$max_rss" 'BEGIN { printf("%.2f", v/1024.0) }')

echo ""
echo "Output: $OUTPUT"
echo "Samples: $valid_samples"
echo "CPU   min/avg/max: ${min_cpu_fmt}% / ${avg_cpu}% / ${max_cpu_fmt}%"
echo "RSSMB min/avg/max: ${min_rss_mb} / ${avg_rss_mb} / ${max_rss_mb}"

cpu_ok=$(awk -v avg="$avg_cpu" 'BEGIN { if (avg < 30.0) print "yes"; else print "no" }')
if [[ "$cpu_ok" == "yes" ]]; then
  echo "CPU target check: PASS (avg < 30%)"
else
  echo "CPU target check: FAIL (avg >= 30%)"
fi
