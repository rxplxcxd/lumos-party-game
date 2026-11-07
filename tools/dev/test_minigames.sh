#!/bin/bash
# Startet jedes Minispiel mit 4 CPUs und speichert Screenshots + Fehlerlog.
G=${GODOT:-/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64}
OUT=${1:-/tmp/mg_shots}
LIST=${2:-"PlankPanic DungeonDrop KartBowling TreasureZipline GhostCastle BarrelChaos LavaSurf TowerBalance HotBomb SlimeSprint"}
mkdir -p "$OUT"
for M in $LIST; do
  rm -rf "$OUT/$M"
  timeout 90 xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 --resolution 1280x720 -- \
    --scene=res://scenes/minigames/$M.tscn --mode=free_play --cpu --shots=4,13,19,26,34,45 --shotdir="$OUT/$M" --quit=50 \
    > "$OUT/$M.log" 2>&1
  echo "$M: $(grep -c -E 'SCRIPT ERROR' "$OUT/$M.log") script errors, $(ls "$OUT/$M" 2>/dev/null | wc -l) shots"
done
