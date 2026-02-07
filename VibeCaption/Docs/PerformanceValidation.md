# Performance Validation Runbook

## Goal
Validate sustained operation quality and ensure average CPU usage stays below 30% on Apple Silicon (M1-class) during normal use.

## Prerequisites
- Build and run VibeCaption.
- Ensure meeting-audio style input is active.
- Keep the app running for at least 60 minutes.

## Sampling Script
Use:
- `bash Scripts/profile_performance.sh --process-name VibeCaption --minutes 60 --interval 1 --output Docs/perf-reports/normal-mode.csv`

Then enable Performance Mode and repeat:
- `bash Scripts/profile_performance.sh --process-name VibeCaption --minutes 60 --interval 1 --output Docs/perf-reports/performance-mode.csv`

## What to Compare
- `avg_cpu_percent`: should be lower in Performance Mode.
- `max_cpu_percent`: should show fewer peaks in Performance Mode.
- `avg_rss_mb` and `max_rss_mb`: should remain stable over time.

## Pass Criteria
- Normal mode average CPU is acceptable for your deployment target.
- Performance mode average CPU is lower than normal mode.
- No sustained memory growth indicating leaks.
- App remains responsive and transcript saving still works after long runs.

