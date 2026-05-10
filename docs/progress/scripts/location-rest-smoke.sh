#!/usr/bin/env bash
# E2E REST konum smoke — register × 2 + couple + POST /locations + GET /current +
# 50m içinde 2 dakika 10 nokta + GET /together = 2 dk + 200m uzağa nokta + tekrar GET /together.
# Önkoşul: API ayakta + Postgres + PostGIS ayakta.

set -euo pipefail
BASE="${BASE:-http://localhost:5049}"
SUFFIX="$(date +%s)"
A_EMAIL="alice-loc-${SUFFIX}@example.com"
B_EMAIL="bob-loc-${SUFFIX}@example.com"
PY='python3 -c'

A=$(curl -sS -X POST "$BASE/auth/register" -H "Content-Type: application/json" \
  -d "{\"email\":\"$A_EMAIL\",\"password\":\"Password123\",\"displayName\":\"Alice\"}")
TA_REFRESH=$(echo "$A" | $PY "import sys,json;print(json.load(sys.stdin)['refreshToken'])")
TA=$(echo "$A" | $PY "import sys,json;print(json.load(sys.stdin)['accessToken'])")

INV=$(curl -sS -X POST "$BASE/couples/invites" -H "Authorization: Bearer $TA")
CODE=$(echo "$INV" | $PY "import sys,json;print(json.load(sys.stdin)['code'])")

B=$(curl -sS -X POST "$BASE/auth/register" -H "Content-Type: application/json" \
  -d "{\"email\":\"$B_EMAIL\",\"password\":\"Password123\",\"displayName\":\"Bob\"}")
TB_REFRESH=$(echo "$B" | $PY "import sys,json;print(json.load(sys.stdin)['refreshToken'])")
TB=$(echo "$B" | $PY "import sys,json;print(json.load(sys.stdin)['accessToken'])")

curl -sS -X POST "$BASE/couples/invites/$CODE/accept" -H "Authorization: Bearer $TB" >/dev/null

# couple_id claim için refresh
TA=$(curl -sS -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$TA_REFRESH\"}" | $PY "import sys,json;print(json.load(sys.stdin)['accessToken'])")
TB=$(curl -sS -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$TB_REFRESH\"}" | $PY "import sys,json;print(json.load(sys.stdin)['accessToken'])")

# Helper: tek nokta gönder. $1=token $2=lat $3=lng $4=offset_seconds (negative=geçmiş)
post_loc() {
  local TOKEN="$1" LAT="$2" LNG="$3" OFF="${4:-0}"
  local TS=$(python3 -c "from datetime import datetime,timezone,timedelta;print((datetime.now(timezone.utc)+timedelta(seconds=$OFF)).isoformat())")
  curl -sS -X POST "$BASE/locations" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"latitude\":$LAT,\"longitude\":$LNG,\"accuracy\":10,\"speed\":0,\"heading\":null,\"batteryLevel\":80,\"isMoving\":false,\"recordedAt\":\"$TS\"}" >/dev/null
}

echo "→ Alice ilk nokta (40.99, 29.02)"
post_loc "$TA" 40.99 29.02 0

echo "→ Bob 'GET /locations/current' Alice'i görüyor mu?"
CUR=$(curl -sS "$BASE/locations/current" -H "Authorization: Bearer $TB")
test -n "$CUR" || { echo "FAIL: empty response"; exit 1; }
GOT_LAT=$(echo "$CUR" | $PY "import sys,json;print(json.load(sys.stdin)['latitude'])")
test "$GOT_LAT" = "40.99" || { echo "FAIL: expected lat 40.99 got $GOT_LAT"; exit 1; }

echo "→ Alice + Bob 50m içinde geçmiş 2 dk için 4 dakikalık bucket dolduruyor (her birinden 4 nokta)"
# 4 dakikaya yayılmış, her dakikaya iki nokta - bucket'lar saatin başlangıcına hizalanmaz ama date_trunc('minute') bizim için çalışır
for i in 0 1 2 3; do
  OFF=$(( -240 + i * 60 + 5 ))
  post_loc "$TA" "$(python3 -c "print(40.99 + 0.00005*$i)")" "$(python3 -c "print(29.02 + 0.00005*$i)")" "$OFF"
  post_loc "$TB" "$(python3 -c "print(40.99 + 0.00005*$i + 0.0001)")" "$(python3 -c "print(29.02 + 0.00005*$i + 0.0001)")" "$OFF"
done

FROM=$(python3 -c "from datetime import datetime,timezone,timedelta;print((datetime.now(timezone.utc)-timedelta(minutes=10)).isoformat())")
TO=$(python3 -c "from datetime import datetime,timezone;print(datetime.now(timezone.utc).isoformat())")

echo "→ GET /locations/together (yakın aralık)"
TOGETHER=$(curl -sS "$BASE/locations/together?from=$FROM&to=$TO" -H "Authorization: Bearer $TA")
echo "  → $TOGETHER"
NEAR_MIN=$(echo "$TOGETHER" | $PY "import sys,json;print(json.load(sys.stdin)['totalMinutes'])")
test "$NEAR_MIN" -ge "1" || { echo "FAIL: yakın bucket'ta togetherMinutes ≥1 bekleniyordu, $NEAR_MIN geldi"; exit 1; }

echo "→ Bob 200m uzağa atar (40.992, 29.022)"
post_loc "$TB" 40.992 29.022 0

echo "→ list (Alice perspektif)"
LIST=$(curl -sS "$BASE/locations?from=$FROM&to=$TO&take=50" -H "Authorization: Bearer $TA")
LIST_COUNT=$(echo "$LIST" | $PY "import sys,json;print(len(json.load(sys.stdin)))")
test "$LIST_COUNT" -ge "5" || { echo "FAIL: expected ≥5 list rows, got $LIST_COUNT"; exit 1; }

echo "✓ Location REST smoke geçti. ($A_EMAIL / $B_EMAIL — couple kuruldu, $LIST_COUNT nokta, $NEAR_MIN dk beraber)"
