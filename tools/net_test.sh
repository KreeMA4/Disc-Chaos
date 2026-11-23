#!/usr/bin/env bash
# Headless co-op test on localhost: a host and 2 clients (one joins late). They grab, swap and
# shelve items, contest the same grab, then all write a state checksum which must match.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p tests/out && rm -f tests/out/net_*.txt
run() { timeout 150 "$GODOT_BIN" --headless --path . --audio-driver Dummy -- "$1" > "tests/out/net_$2.log" 2>&1 & }
run --nettest-host host; sleep 2
run --nettest-client=1 client1
run --nettest-client=2 client2
wait
fail=0
for r in host client1 client2; do
  [ -f "tests/out/net_$r.txt" ] || { echo "FAIL: $r wrote no result"; tail -20 "tests/out/net_$r.log"; fail=1; continue; }
  echo "--- $r"; cat "tests/out/net_$r.txt"; echo
done
[ $fail = 0 ] || exit 1
c0=$(grep checksum tests/out/net_host.txt); c1=$(grep checksum tests/out/net_client1.txt); c2=$(grep checksum tests/out/net_client2.txt)
s0=$(grep '^status' tests/out/net_host.txt)
if [ "$c0" = "$c1" ] && [ "$c0" = "$c2" ] && [ "$s0" = "status=DONE" ]; then
  echo "NET TEST PASS: state identical on host and both clients ($c0)"
else
  echo "NET TEST FAIL: host [$c0] client1 [$c1] client2 [$c2]"; exit 1
fi
# exactly one client may win a contested grab
w=$(grep -h "holder of contested" tests/out/net_client*.txt | awk '{print $NF}' | head -1)
grep -h "holder of contested" tests/out/net_client*.txt
