#!/bin/bash
# Lokaler Online-Test: RTDB-Mock + Host + Client (native, Relay-Transport).
# Aufruf: tools/dev/net_test.sh <ausgabeordner> [race|sumo_shove] [track]
G=${GODOT:-/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64}
OUT=${1:-/tmp/net_test}
GAME=${2:-race}
TRACK=${3:-lumos_ring}
mkdir -p "$OUT"
CODE_FILE="$OUT/code.txt"
rm -f "$CODE_FILE"
python3 tools/dev/rtdb_mock.py 9123 > "$OUT/mock.log" 2>&1 &
MOCK=$!
sleep 1
export LUMOS_RTDB_URL=http://127.0.0.1:9123
COMMON="--path . --rendering-driver opengl3 --resolution 960x540"
LUMOS_NET_TEST_UID=hostA timeout 150 xvfb-run -a -s "-screen 0 960x540x24" $G $COMMON -- --net-test=host --net-autodrive --net-game=$GAME --track=$TRACK --laps=1 \
  --net-code-file="$CODE_FILE" --shots=40,60 --shotdir="$OUT/host" --quit=140 > "$OUT/host.log" 2>&1 &
H=$!
LUMOS_NET_TEST_UID=clientB timeout 150 xvfb-run -a -s "-screen 0 960x540x24" $G $COMMON -- --net-test=join --net-autodrive \
  --net-code-file="$CODE_FILE" --shots=40,60 --shotdir="$OUT/client" --quit=140 > "$OUT/client.log" 2>&1 &
C=$!
wait $H $C
kill $MOCK 2>/dev/null
echo "Host:   $(grep -c 'SCRIPT ERROR' "$OUT/host.log") Skriptfehler"; grep "\[NET\]" "$OUT/host.log" | tail -8
echo "Client: $(grep -c 'SCRIPT ERROR' "$OUT/client.log") Skriptfehler"; grep "\[NET\]" "$OUT/client.log" | tail -8
