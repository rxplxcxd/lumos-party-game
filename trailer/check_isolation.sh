#!/bin/bash
# Prüft, dass die Trailer-Produktion vollständig vom Spiel getrennt ist und selbst lauffähig bleibt.
#   bash trailer/check_isolation.sh        → "TRAILER-TRENNUNG OK" bzw. Fehlerliste, Exit-Code 0/1
#
#  1. Kein Spielteil (Autoloads, Skripte, Szenen, Werkzeuge, Web-Hülle, Projekt- und Export-Einstellungen)
#     verweist auf den Trailer-Ordner – das Spiel kann ihn weder laden noch starten.
#  2. Der Trailer ist nicht im Web-/Linux-Export enthalten.
#  3. Hauptszene und Autoloads des Spiels sind keine Trailer-Dateien.
#  4. Alle Trailer-Skripte und -Szenen laden fehlerfrei (strenge Typprüfung wie im Spiel).
#  5. Der Trailer selbst lädt und läuft (kurz ab Sekunde 94 bis zum Ende) ohne Skriptfehler.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT_BIN:-${GODOT:-./godot}}
FAIL=0
fail() { echo "FEHLER $*"; FAIL=1; }

HITS=$(grep -rIl --exclude-dir=.godot -E "res://trailer|trailer/trailer\.gd|Trailer\.tscn" \
  autoload scripts scenes tools web project.godot export_presets.cfg 2>/dev/null)
[ -n "$HITS" ] && fail "Spieldateien verweisen auf den Trailer: $HITS"
grep -q "res://trailer" export_presets.cfg && fail "Trailer steht in der Export-Liste"
grep -E '^run/main_scene|^[A-Za-z]+="\*res://' project.godot | grep -qi trailer && fail "Hauptszene/Autoload zeigt auf den Trailer"
CHK=$(timeout 300 "$GODOT" --headless --path . res://tools/dev/Check.tscn -- --check-dirs=res://trailer 2>&1)
echo "$CHK" | grep -qE "checked [1-9][0-9]* files, 0 problems" || { fail "Trailer-Dateien laden nicht fehlerfrei:"; echo "$CHK" | grep -E "LOAD FAIL|SCRIPT INVALID|Parse Error|SCRIPT ERROR|checked" | head -20; }
LOG=$(timeout 180 "$GODOT" --headless --path . res://trailer/Trailer.tscn -- --trailer-from=94 2>&1)
echo "$LOG" | grep -q "SCRIPT ERROR\|Parse Error\|Failed to load" && { fail "Trailer läuft nicht fehlerfrei:"; echo "$LOG" | grep -A3 "SCRIPT ERROR\|Parse Error\|Failed to load" | head -20; }
echo "$LOG" | grep -q "\[TRAILER\]" || fail "Trailer ist nicht gestartet"
[ $FAIL -eq 0 ] && echo "TRAILER-TRENNUNG OK"
exit $FAIL
