#!/bin/bash
# Test SecureChat: 1 server + 2 clients (scripted stdin)
cd "$(dirname "$0")"
PY="F:/TH_LTANTT/TH_B3/.venv/Scripts/python"

"$PY" server.py > server.log 2>&1 &
SPID=$!
sleep 2

{ printf 'phuoc\n'; sleep 2; printf 'xin chao\n'; sleep 2; printf 'day la ung dung chat ma hoa\n'; sleep 6; printf 'exit\n'; } | "$PY" client.py > client1.log 2>&1 &
C1=$!
{ printf 'ty\n'; sleep 5; printf 'hello\n'; sleep 2; printf 'duoc ma hoa bang ssl\n'; sleep 5; printf 'exit\n'; } | "$PY" client.py > client2.log 2>&1 &
C2=$!

wait $C1 $C2
sleep 1
kill $SPID 2>/dev/null
wait $SPID 2>/dev/null

echo '=== server.log ==='
cat server.log
echo '=== client1.log (phuoc) ==='
cat client1.log
echo '=== client2.log (ty) ==='
cat client2.log
