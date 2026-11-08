#!/bin/bash
# Testet Minispiele in einer Kategorie: tools/dev/test_cat.sh <out> <cat> "<Szenen>"
G=${GODOT:-/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64}
OUT=$1; CAT=$2; LIST=$3
mkdir -p "$OUT"
for M in $LIST; do
  timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 --resolution 1280x720 -- \
    --scene=res://scenes/minigames/$M.tscn --mode=free_play --cpu --cat=$CAT --solo=0 --shots=6,14,24,40,60 --shotdir="$OUT/$M-$CAT" --quit=75 \
    > "$OUT/$M-$CAT.log" 2>&1
  echo "$M ($CAT): $(grep -c 'SCRIPT ERROR' "$OUT/$M-$CAT.log") Skriptfehler, $(ls "$OUT/$M-$CAT" 2>/dev/null | wc -l) Bilder"
done
