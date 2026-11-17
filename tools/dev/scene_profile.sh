#!/usr/bin/env bash
# Leistungsprofil aller Szenen nacheinander (nicht parallel – parallele Läufe verfälschen die Bildzeiten).
#   tools/dev/scene_profile.sh <ziele.txt> <ausgabe.jsonl> [--xvfb]
# Ziele je Zeile: menu · board:<id> · track:<id> · mg:<id> · boss:<id> · mode:<id> (Liste: tools/dev/inventory.gd)
# Spielzeit je Ziel: Brett 40 s, Strecke 45 s, Minispiel/Boss bis zum Ende (höchstens 60 s), Menü/Modi 20 s.
set -u
targets="$1"; out="$2"; mode="${3:-}"
cd "$(dirname "$0")/../.."
: > "$out"
while read -r t; do
	[ -z "$t" ] && continue
	case "$t" in
		board:*) secs=40 ;; track:*) secs=45 ;; mg:*|boss:*) secs=60 ;; *) secs=20 ;;
	esac
	if [ "$mode" = "--xvfb" ]; then
		# Render-Zählwerte bei Grafikstufe „Hoch“, kürzeres Fenster (Software-Rasterung ist langsam)
		line=$(timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" ./godot --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/scene_profile.gd --target="$t" --secs=12 --quality=high 2>/dev/null | grep '^PROFILE ' | tail -1)
	else
		line=$(timeout 600 ./godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/scene_profile.gd --target="$t" --secs="$secs" 2>/dev/null | grep '^PROFILE ' | tail -1)
	fi
	if [ -z "$line" ]; then
		echo "{\"target\": \"$t\", \"error\": \"kein Ergebnis (Absturz/Zeitlimit)\"}" >> "$out"
	else
		echo "${line#PROFILE }" >> "$out"
	fi
done < "$targets"
echo "fertig: $(wc -l < "$out") Ziele → $out"
