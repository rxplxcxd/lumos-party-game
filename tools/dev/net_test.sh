#!/bin/bash
# Lokaler Online-Test: RTDB-Mock + Host + Client (native Instanzen, Relay-Transport).
# Die lokalen Spieler fahren/laufen per KI (--net-autodrive). Ergebnis: Logs mit Nachrichtenzählern
# und gleichen Platzierungen auf beiden Geräten.
#
# Aufruf: tools/dev/net_test.sh <ausgabeordner> [race|party|<minispiel-id>] [track|brett]
#   party: Online-Brettspiel (Lockstep); prüft, dass beide Geräte denselben Brettzustand haben.
#   HEADLESS=1  ohne Grafik (CI), sonst xvfb mit Screenshots
G=${GODOT:-/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64}
OUT=${1:-/tmp/net_test}
GAME=${2:-race}
TRACK=${3:-lumos_ring}
DUR=${DUR:-150}
[ "$GAME" = "party" ] && DUR=${DUR_PARTY:-330}
[ "$GAME" = "party" ] && [ "$TRACK" = "lumos_ring" ] && TRACK=meadow
PORT=${PORT:-9123}
mkdir -p "$OUT"
CODE_FILE="$OUT/code.txt"
rm -f "$CODE_FILE"
python3 tools/dev/rtdb_mock.py "$PORT" > "$OUT/mock.log" 2>&1 &
MOCK=$!
sleep 1
export LUMOS_RTDB_URL=http://127.0.0.1:$PORT
if [ "$HEADLESS" = "1" ]; then
  RUN="$G --headless --path ."
  SHOTS_H=""
  SHOTS_C=""
else
  RUN="xvfb-run -a -s '-screen 0 960x540x24' $G --path . --rendering-driver opengl3 --resolution 960x540"
  SHOTS_H="--shots=40,60 --shotdir=$OUT/host"
  SHOTS_C="--shots=40,60 --shotdir=$OUT/client"
fi
LUMOS_NET_TEST_UID=hostA timeout $((DUR + 20)) bash -c "$RUN -- --net-test=host --net-autodrive --net-game=$GAME --track=$TRACK --net-board=$TRACK --net-rounds=5 --laps=1 --net-code-file=$CODE_FILE $SHOTS_H --quit=$DUR" > "$OUT/host.log" 2>&1 &
H=$!
LUMOS_NET_TEST_UID=clientB timeout $((DUR + 20)) bash -c "$RUN -- --net-test=join --net-autodrive --net-code-file=$CODE_FILE $SHOTS_C --quit=$DUR" > "$OUT/client.log" 2>&1 &
C=$!
wait $H $C
kill $MOCK 2>/dev/null
FAIL=0
if [ "$GAME" = "party" ]; then
  grep -o "\[NET\] Brett.*" "$OUT/host.log" > "$OUT/host.digest"
  grep -o "\[NET\] Brett.*" "$OUT/client.log" > "$OUT/client.digest"
  N=$(wc -l < "$OUT/client.digest")
  echo "Brett-Zustände: Host $(wc -l < "$OUT/host.digest"), Client $N"
  if [ "$N" -lt 3 ] || ! diff <(head -n "$N" "$OUT/host.digest") "$OUT/client.digest" > "$OUT/digest.diff"; then
    echo "Brettzustand weicht ab oder zu kurz (siehe digest.diff)"; FAIL=1
  else
    echo "Brettzustand identisch ✓"
  fi
  for W in host client; do
    E=$(grep -c "SCRIPT ERROR" "$OUT/$W.log"); echo "$W: $E Skriptfehler"; [ "$E" != "0" ] && FAIL=1
  done
  exit $FAIL
fi
for W in host client; do
  E=$(grep -c "SCRIPT ERROR" "$OUT/$W.log")
  echo "$W: $E Skriptfehler"
  grep -E "\[NET\] (Rennende|Minispiel-Ende|Start-Countdown)" "$OUT/$W.log"
  [ "$E" != "0" ] && FAIL=1
  grep -qE "\[NET\] (Rennende|Minispiel-Ende)" "$OUT/$W.log" || { echo "$W: Spiel wurde nicht beendet"; FAIL=1; }
done
exit $FAIL
