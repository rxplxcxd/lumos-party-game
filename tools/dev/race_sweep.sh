#!/bin/bash
# Fährt auf allen (oder den genannten) Strecken je ein komplettes Rennen mit 8 CPU-Karts und fasst die Messwerte zusammen.
#   bash tools/dev/race_sweep.sh [ausgabe.jsonl] [strecke1 strecke2 …]      RACE_ARGS="--laps=3 --level=2"
G=${GODOT:-./godot}
OUT=${1:-/tmp/race_sweep.jsonl}
shift
IDS="$*"
if [ -z "$IDS" ]; then
  IDS=$(sed -n '/^const TRACKS := \[/,/^\]/p' autoload/game_state.gd | grep -o '"id": "[a-z_]*"' | sed 's/"id": "\(.*\)"/\1/')
fi
: > "$OUT"
FAIL=0
for ID in $IDS; do
  LOG=$(timeout 600 $G --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/race_test.gd --track=$ID $RACE_ARGS 2>&1)
  LINE=$(echo "$LOG" | grep '^RACE ' | tail -1 | sed 's/^RACE //')
  ERR=$(echo "$LOG" | grep -c 'SCRIPT ERROR')
  [ -z "$LINE" ] && { LINE="{\"track\": \"$ID\", \"error\": \"absturz\"}"; FAIL=1; }
  [ "$ERR" -gt 0 ] && FAIL=1
  echo "{\"skriptfehler\": $ERR, \"r\": $LINE}" >> "$OUT"
  echo "$ID: $(echo "$LINE" | cut -c1-230) · Skriptfehler $ERR"
  echo "$LOG" | grep '^RACE-WARN' | sed "s/^/  $ID: /"
done
exit $FAIL
