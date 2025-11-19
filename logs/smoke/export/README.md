Debug Lab evidence exports live here.

Each `debug_lab_<timestamp>.zip` contains:
- `manifest.json` summarizing the fixture, anomaly log path, and counts.
- `logs/debug_lab_entries.json` with the visible UI log, trimmed to 200 events.
- `streams/*.json` covering FRB audio metrics, onset samples, and `/metrics`.
- `commands/param_patches.json` plus `cli_reference.txt` for keynote decks.

The exporter also writes a sibling `debug_lab_<timestamp>.txt` file that
duplicates the CLI references for quick copy/paste during demos.
