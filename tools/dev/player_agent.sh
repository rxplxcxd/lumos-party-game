#!/bin/bash
# Lumos Player Agent über alle Minispiele (siehe tools/dev/player_agent.gd).
#   bash tools/dev/player_agent.sh <ausgabeordner> [jobs=4] [nur-diese-id …]
# Je Spiel: „mimic“ in jeder Kategorie (Start-Platz 1 als Mensch an der Tastatur, 2 Zufallsstartwerte in der ersten
# Kategorie), dazu „idle“, „random“ und „mash“ in der ersten Kategorie. Ergebnis: <ordner>/agent.jsonl
# (eine Zeile je Lauf, inkl. Skriptfehler-Zähler) → Auswertung: python3 tools/dev/agent_report.py <ordner>
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT=$(realpath -m "${1:-build/agent}"); JOBS=${2:-4}; shift $(( $# > 2 ? 2 : $# ))
GODOT=${GODOT:-./godot}
mkdir -p "$OUT/logs"; : > "$OUT/agent.jsonl"
[ -f data/project_inventory.json ] || timeout 300 $GODOT --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/inventory.gd >/dev/null 2>&1
python3 - "$@" > "$OUT/jobs.txt" <<'PY'
import json, sys
only = set(sys.argv[1:])
for m in json.load(open("data/project_inventory.json"))["minigames"]["list"]:
    if only and m["id"] not in only: continue
    cats = m["cats"] or ["ffa"]
    for k, c in enumerate(cats):
        print(m["id"], c, "mimic", 1)
        if k == 0:
            print(m["id"], c, "mimic", 2)
            for s in ("idle", "random", "mash"): print(m["id"], c, s, 1)
PY
run_one() {
  id=$1; cat=$2; strat=$3; seed=$4; log="$OUT/logs/${id}_${cat}_${strat}_${seed}.log"
  for try in 1 2; do   # Die Engine stürzt bei parallelem Start vereinzelt schon vor dem Spiel ab (Signal 11) – einmal wiederholen
    timeout 420 $GODOT --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/player_agent.gd \
      --only=$id --cat=$cat --strategy=$strat --seed=$seed > "$log" 2>&1
    rc=$?
    grep -q "^AGENT " "$log" && break
  done
  errs=$(grep -c "SCRIPT ERROR" "$log"); warn=$(grep -c "^ERROR:\|^WARNING:" "$log")
  line=$(grep -m1 "^AGENT " "$log" | cut -c7-)
  [ -z "$line" ] && line="{\"id\":\"$id\",\"cat\":\"$cat\",\"strategy\":\"$strat\",\"seed\":$seed,\"end\":\"kein_ergebnis\",\"rc\":$rc}"
  first=$(grep -m1 -A3 "SCRIPT ERROR" "$log" | tr '\n' ' ' | cut -c1-300 | sed 's/"/'"'"'/g')
  echo "${line%\}},\"script_errors\":$errs,\"engine_msgs\":$warn,\"first_error\":\"$first\"}" >> "$OUT/agent.jsonl"
}
export -f run_one; export OUT GODOT
xargs -P "$JOBS" -L 1 bash -c 'run_one "$@"' _ < "$OUT/jobs.txt"
echo "AGENT-LAUF fertig: $(wc -l < "$OUT/agent.jsonl") Läufe → $OUT/agent.jsonl"
