#!/bin/bash
# Test NetRecon web app: start Flask, GET /, POST /scan, stop
cd "$(dirname "$0")"
PY="F:/TH_LTANTT/TH_B3/.venv/Scripts/python"

"$PY" app.py > app_test.log 2>&1 &
APID=$!
sleep 4

echo '=== GET / (title + form fields) ==='
curl -s http://127.0.0.1:5000/ | grep -oE '<title>[^<]*</title>|name="[a-z]+"' | sort -u

echo '=== POST /scan target=127.0.0.1 ports=22,80 mode=scan ==='
curl -s --max-time 120 -X POST -d "target=127.0.0.1&ports=22,80&mode=scan&email=test@example.com" http://127.0.0.1:5000/scan -o scan_result.html
grep -oE 'Kết quả[^<]*|SCAN|scan[^<]*' scan_result.html | head -10
echo "scan_result.html size: $(wc -c < scan_result.html) bytes"

echo '=== app log ==='
cat app_test.log

kill $APID 2>/dev/null
wait $APID 2>/dev/null
