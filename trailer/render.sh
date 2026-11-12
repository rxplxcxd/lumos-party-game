#!/bin/bash
# Rendert den Trailer „Lumos Party – Best adventures are shared.“ als fertiges Video – das Spielprojekt bleibt
# dabei unverändert.
#
#   bash trailer/render.sh [ausgabeordner] [breite] [höhe] [fps]      Standard: trailer_out 3840 2160 60
#   TRAILER_QUICK=1 bash trailer/render.sh /tmp/vorschau 1280 720 30  schnelle Kontrollfassung (ohne MSAA, kleine Schatten)
#
# Ablauf:
#   1. Render-Projekt: ein temporärer Ordner, der auf dieselben Projektdateien verweist (Symlinks), mit eigener
#      project.godot (Fenstergröße, MJPEG-Qualität). Der Movie Maker nimmt die Bildgröße aus den Projekt-
#      einstellungen – so bekommt nur der Trailer 4K, das Spiel behält seine Einstellungen.
#   2. Movie Maker: feste Bildrate, jedes Bild wird vollständig gerendert (kein Ruckeln, bildgenau wiederholbar),
#      Ton wird verlustfrei mitgeschrieben. Der Trailer schreibt seine Schnittliste (marks.json) für die Prüfung.
#   3. ffmpeg: Lautheit zweistufig auf −14 LUFS / −1,5 dBTP, H.264 High (yuv420p, +faststart), AAC 256 kbit/s.
#      Dazu eine 1080p-Fassung aus dem 4K-Master (schärfer als direkt in 1080p gerendert).
#   4. Prüfung: trailer/qa.py (Format, Schwarzbilder, unerwartete Sprünge, Standbilder, Tonaussetzer, Clipping)
#      und Kontaktbögen zur Sichtkontrolle.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
GODOT=${GODOT:-$ROOT/godot}
OUT=$(realpath -m "${1:-trailer_out}")
W=${2:-3840}
H=${3:-2160}
FPS=${4:-60}
mkdir -p "$OUT"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lumos_trailer.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# 1. Render-Projekt
mkdir -p "$WORK/proj"
for f in $(ls -A "$ROOT"); do
  case "$f" in project.godot|.git|trailer_out) continue ;; esac
  ln -s "$ROOT/$f" "$WORK/proj/$f"
done
python3 - "$ROOT/project.godot" "$WORK/proj/project.godot" "$W" "$H" <<'EOF'
import sys
src, dst, w, h = sys.argv[1:5]
s = open(src).read()
add = "window/size/window_width_override=%s\nwindow/size/window_height_override=%s\n" % (w, h)
s = s.replace("window/size/viewport_height=720\n", "window/size/viewport_height=720\n" + add, 1)
s += "\n[editor]\n\nmovie_writer/video_quality=0.95\nmovie_writer/mix_rate=48000\n"
open(dst, "w").write(s)
EOF
grep -q "window_width_override=$W" "$WORK/proj/project.godot" || { echo "Render-Projekt: Fenstergröße nicht gesetzt"; exit 1; }

# 2. Aufnahme
if [ -n "${TRAILER_QUICK:-}" ]; then
  QUALITY="--trailer-msaa=0 --trailer-shadow=2048"
else
  QUALITY="--trailer-msaa=2 --trailer-shadow=8192"
fi
RUN=("$GODOT" --path "$WORK/proj" --write-movie "$WORK/raw.avi" --fixed-fps "$FPS" res://trailer/Trailer.tscn --
  --trailer-marks="$OUT/marks.json" $QUALITY)
echo "[RENDER] ${W}x${H} @ ${FPS} fps → $OUT"
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
  xvfb-run -a -s "-screen 0 ${W}x${H}x24" "${RUN[@]}" > "$OUT/render.log" 2>&1
else
  "${RUN[@]}" > "$OUT/render.log" 2>&1
fi
grep -E "TRAILER|recorded in|average" "$OUT/render.log" || true
if grep -q "SCRIPT ERROR" "$OUT/render.log"; then
  echo "[RENDER] Skriptfehler während der Aufnahme:"; grep -A3 "SCRIPT ERROR" "$OUT/render.log" | head -20; exit 1
fi
[ -s "$OUT/marks.json" ] || { echo "[RENDER] Trailer nicht bis zum Ende gelaufen (keine Schnittliste)"; exit 1; }

# 3. Lautheit messen (Durchgang 1) und anwenden (Durchgang 2), dann kodieren
LN=$(ffmpeg -hide_banner -nostats -i "$WORK/raw.avi" -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 \
  | python3 -c "import sys,json; t=sys.stdin.read(); d=json.loads(t[t.rfind('{'):]); print('measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s' % (d['input_i'], d['input_tp'], d['input_lra'], d['input_thresh'], d['target_offset']))")
AF="loudnorm=I=-14:TP=-1.5:LRA=11:$LN:linear=true,aresample=48000"
NAME=Lumos_Party_Trailer
LEVEL=5.2; [ "$H" -le 1080 ] && LEVEL=4.2
ffmpeg -v error -y -i "$WORK/raw.avi" -af "$AF" -c:v libx264 -preset slow -tune animation -crf 16 -profile:v high \
  -level:v $LEVEL -pix_fmt yuv420p -r "$FPS" -c:a aac -b:a 256k -ar 48000 -movflags +faststart "$OUT/${NAME}_${H}p${FPS}.mp4"
if [ "$H" -gt 1080 ]; then
  ffmpeg -v error -y -i "$OUT/${NAME}_${H}p${FPS}.mp4" -vf "scale=1920:1080:flags=lanczos" -c:v libx264 -preset slow \
    -tune animation -crf 17 -profile:v high -level:v 4.2 -pix_fmt yuv420p -c:a copy -movflags +faststart \
    "$OUT/${NAME}_1080p${FPS}.mp4"
fi
rm -f "$WORK/raw.avi"

# 4. Prüfung
python3 trailer/qa.py "$OUT/${NAME}_${H}p${FPS}.mp4" --marks="$OUT/marks.json" --expect="${W}x${H}@${FPS}" \
  --sheets="$OUT/sheets" | tee "$OUT/qa.txt"
ls -la "$OUT"
