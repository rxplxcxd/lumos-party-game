#!/bin/bash
# Lokaler Online-Test: RTDB-Mock + Host + Gäste (native Instanzen, Relay-Transport).
# Die lokalen Spieler fahren/laufen per KI (--net-autodrive). Ergebnis: Logs mit Nachrichtenzählern
# und gleichen Platzierungen auf allen Geräten.
#
# Aufruf: tools/dev/net_test.sh <ausgabeordner> [race|party|<minispiel-id>] [track|brett]
#   party: Online-Brettspiel (Lockstep); prüft, dass alle Geräte denselben Brettzustand haben.
#   HEADLESS=1   ohne Grafik (CI), sonst xvfb mit Screenshots
#   CLIENTS=2    Anzahl Gäste (Standard 1, höchstens 3)
#   HUMAN=1      der erste Gast spielt als „Mensch“ (keine KI; drückt Knöpfe selbst, --net-autopress)
#   HEROES="knight ranger mage"  Figur je Gerät (Host zuerst)
# Prüft zusätzlich: identische Spielerliste (Plätze, Figuren, Mensch/CPU) auf allen Geräten, eindeutige Plätze
# und dass Bedienelemente nur für den eigenen Platz erscheinen.
G=${GODOT:-/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64}
OUT=${1:-/tmp/net_test}
GAME=${2:-race}
TRACK=${3:-lumos_ring}
DUR=${DUR:-150}
[ "$GAME" = "party" ] && DUR=${DUR_PARTY:-330}
[ "$GAME" = "athlon" ] && DUR=${DUR_ATHLON:-150}
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
  SHOTS_H="--shots=${SHOTS:-40,60} --shotdir=$OUT/host"
  SHOTS_C="--shots=${SHOTS:-40,60} --shotdir=$OUT/client"
fi
CLIENTS=${CLIENTS:-1}
read -r -a HERO_LIST <<< "${HEROES:-}"
hero_arg() { [ -n "${HERO_LIST[$1]:-}" ] && echo "--net-hero=${HERO_LIST[$1]}"; }
LUMOS_NET_TEST_DEV=devHost LUMOS_NET_TEST_UID=hostA timeout $((DUR + 20)) bash -c "$RUN -- --net-test=host --net-autodrive --net-players=$((CLIENTS + 1)) --net-game=$GAME --track=$TRACK --net-board=$TRACK --net-rounds=5 --laps=1 --net-code-file=$CODE_FILE $(hero_arg 0) $SHOTS_H ${EXTRA:-} --quit=$DUR" > "$OUT/host.log" 2>&1 &
PIDS="$!"
WHO="host"
for K in $(seq 1 "$CLIENTS"); do
  NAME=client; [ "$K" -gt 1 ] && NAME="client$K"
  DRIVE="--net-autodrive"; [ "$K" = "1" ] && [ "${HUMAN:-0}" = "1" ] && DRIVE="--net-autopress"
  SC=""; [ -n "$SHOTS_C" ] && SC="--shots=${SHOTS:-40,60} --shotdir=$OUT/$NAME"
  sleep 0.4
  LUMOS_NET_TEST_DEV=dev$K LUMOS_NET_TEST_UID=client$K timeout $((DUR + 20)) bash -c "$RUN -- --net-test=join $DRIVE --net-code-file=$CODE_FILE $(hero_arg "$K") $SC ${EXTRA:-} --quit=$DUR" > "$OUT/$NAME.log" 2>&1 &
  PIDS="$PIDS $!"
  WHO="$WHO $NAME"
done
wait $PIDS
kill $MOCK 2>/dev/null
FAIL=0
# --- Spielerliste: auf allen Geräten identisch, jeder Platz genau einmal -----------------------------------
grep -o "\[NET\] Roster.*" "$OUT/host.log" | head -1 > "$OUT/host.roster"
if [ -s "$OUT/host.roster" ]; then
  echo "Spielerliste: $(sed 's/\[NET\] Roster //' "$OUT/host.roster")"
  SLOTS=""
  for W in $WHO; do
    grep -o "\[NET\] Roster.*" "$OUT/$W.log" | head -1 > "$OUT/$W.roster"
    if ! diff -q "$OUT/host.roster" "$OUT/$W.roster" > /dev/null; then echo "$W: Spielerliste weicht ab"; FAIL=1; fi
    S=$(grep -o "\[NET\] Ich bin Platz [0-9]*" "$OUT/$W.log" | head -1 | grep -o "[0-9]*$")
    SLOTS="$SLOTS $S"
    # Bedienelemente nur für den eigenen Platz
    BAD=$(grep "\[NET\] Bedienung Platz" "$OUT/$W.log" | awk '{p=$4; e=$7; gsub(/\)/,"",e); sub(/:$/,"",e); if (p!=e) print}' | head -3)
    [ -n "$BAD" ] && { echo "$W: Bedienelemente für fremden Platz: $BAD"; FAIL=1; }
  done
  DUP=$(echo $SLOTS | tr ' ' '\n' | sort | uniq -d)
  if [ -n "$DUP" ] || [ "$(echo $SLOTS | wc -w)" != "$((CLIENTS + 1))" ]; then echo "Plätze nicht eindeutig: $SLOTS"; FAIL=1; else echo "Plätze eindeutig:$SLOTS ✓"; fi
  if [ "${HUMAN:-0}" = "1" ]; then
    NU=$(grep -c "\[NET\] Bedienung Platz" "$OUT/client.log")
    echo "Mensch-Gast: $NU eigene Bedienungen"
    [ "$NU" -lt 1 ] && [ "$GAME" = "party" ] && { echo "Mensch-Gast hat nie bedient"; FAIL=1; }
  fi
fi
if [ "$GAME" = "party" ] || [ "$GAME" = "athlon" ]; then
  grep -o "\[NET\] \(Brett\|Athlon\).*" "$OUT/host.log" > "$OUT/host.digest"
  for W in $WHO; do
    [ "$W" = "host" ] && continue
    grep -o "\[NET\] \(Brett\|Athlon\).*" "$OUT/$W.log" > "$OUT/$W.digest"
    N=$(wc -l < "$OUT/$W.digest")
    echo "Brett-Zustände: Host $(wc -l < "$OUT/host.digest"), $W $N"
    if [ "$N" -lt 3 ] || ! diff <(head -n "$N" "$OUT/host.digest") "$OUT/$W.digest" > "$OUT/$W.digest.diff"; then
      echo "$W: Brettzustand weicht ab oder zu kurz (siehe $W.digest.diff)"; FAIL=1
    else
      echo "$W: Brettzustand identisch ✓"
    fi
    R=$(grep -c "\[NET\] Resync vom Host" "$OUT/$W.log"); [ "$R" != "0" ] && echo "$W: $R Korrektur(en) vom Host übernommen"
  done
  for W in $WHO; do
    E=$(grep -c "SCRIPT ERROR" "$OUT/$W.log"); echo "$W: $E Skriptfehler"; [ "$E" != "0" ] && FAIL=1
  done
  exit $FAIL
fi
for W in $WHO; do
  E=$(grep -c "SCRIPT ERROR" "$OUT/$W.log")
  echo "$W: $E Skriptfehler"
  grep -E "\[NET\] (Rennende|Minispiel-Ende|Start-Countdown)" "$OUT/$W.log"
  [ "$E" != "0" ] && FAIL=1
  grep -qE "\[NET\] (Rennende|Minispiel-Ende)" "$OUT/$W.log" || { echo "$W: Spiel wurde nicht beendet"; FAIL=1; }
done
exit $FAIL
