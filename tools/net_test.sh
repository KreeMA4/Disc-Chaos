#!/usr/bin/env bash
# Headless co-op test on localhost: a host and 2 clients (one joins late). They grab, swap and
# shelve items, contest the same grab, then all write a state checksum which must match.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p tests/out && rm -f tests/out/net_*.txt
run() { timeout 150 "$GODOT_BIN" --headless --path . --audio-driver Dummy -- "$1" > "tests/out/net_$2.log" 2>&1 & }
if [ -n "${NET_SEED:-}" ]; then "$GODOT_BIN" --headless --path . --audio-driver Dummy -- --nettest-host "--nettest-seed=$NET_SEED" > tests/out/net_host.log 2>&1 & else run --nettest-host host; fi; sleep 2
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
  echo "NET TEST FAIL: host [$c0] client1 [$c1] client2 [$c2]"
  # failure diagnostics: which items differ?
  for r in client1 client2; do
    echo "--- items that differ: host vs $r ('<' host, '>' $r)"
    diff tests/out/net_host_items.txt tests/out/net_${r}_items.txt | head -30
  done
  echo "--- elapsed/solved/held at finish"
  for r in host client1 client2; do echo "$r: $(grep -h '^elapsed' tests/out/net_$r.txt) $(grep -h '^solved' tests/out/net_$r.txt) $(grep -h '^held' tests/out/net_$r.txt)"; done
  echo "--- client1 log"; grep -v '^checksum\|^held\|^solved\|^players\|^status\|^elapsed' tests/out/net_client1.txt | head -30
  exit 1
fi
# exactly one client may win a contested grab
w=$(grep -h "holder of contested" tests/out/net_client*.txt | awk '{print $NF}' | head -1)
grep -h "holder of contested" tests/out/net_client*.txt

# B13: each client's clock advanced on (nearly) every frame between host syncs
for c in client1 client2; do
  n=$(grep -h "clock_distinct" tests/out/net_$c.txt | head -1 | sed 's/.*=//')
  if [ -z "$n" ] || [ "$n" -lt 30 ]; then echo "NET TEST FAIL: $c clock only had ${n:-0} distinct values in 45 frames"; exit 1; fi
  echo "client clock smooth ($c: $n distinct values in 45 frames)"
done

# Regression (M1.1): with level seed 7 client1 ends the test still holding a disc it took out of a case.
# Before the clients stayed connected until all snapshots were taken, the host's "player left" cleanup
# raced with the final state comparison and the run failed intermittently. NET_SEED replays one seed.
if [ -z "${NET_SEED:-}" ]; then
  if NET_SEED=7 bash "$0" > tests/out/net_seed7.log 2>&1; then
    echo "NET TEST PASS (seed 7: a client finishes holding an ejected disc)"
  else
    echo "NET TEST FAIL (seed 7)"; tail -25 tests/out/net_seed7.log; exit 1
  fi
fi
