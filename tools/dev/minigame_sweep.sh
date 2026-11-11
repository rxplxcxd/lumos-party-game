#!/bin/bash
# Spielt alle Minispiele (je erste Kategorie) mit 4 CPUs im Schnellvorlauf und fasst die Ergebnisse zusammen.
#   bash tools/dev/minigame_sweep.sh [ausgabe.jsonl] [id1 id2 …]
G=${GODOT:-./godot}
OUT=${1:-/tmp/minigame_sweep.jsonl}
shift
IDS="$*"
if [ -z "$IDS" ]; then
  IDS=$(grep -o '{"id": "[a-z0-9_]*", "name": "[^"]*", "scene"' autoload/game_state.gd | sed 's/{"id": "\([a-z0-9_]*\)".*/\1/')
fi
: > "$OUT"
for ID in $IDS; do
  LOG=$(timeout 240 $G --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/minigame_sweep.gd --only=$ID 2>&1)
  LINE=$(echo "$LOG" | grep '^SWEEP ' | tail -1 | sed 's/^SWEEP //')
  ERR=$(echo "$LOG" | grep -c 'SCRIPT ERROR')
  [ -z "$LINE" ] && LINE="{\"id\": \"$ID\", \"end\": \"absturz\"}"
  echo "{\"skriptfehler\": $ERR, \"r\": $LINE}" >> "$OUT"
  echo "$ID: $(echo "$LINE" | cut -c1-160) · Skriptfehler $ERR"
done
