#!/usr/bin/env bash
# E2E REST chat smoke — register × 2 + invite + accept + send + idempotency + list + mark-read.
# Önkoşul: API ayakta + Postgres ayakta. Önceden alice2/bob2 kayıtlıysa fail edebilir;
# her smoke koşumunda yeni e-posta önekleri kullanmak iyi pratik.

set -euo pipefail
BASE="${BASE:-http://localhost:5049}"
SUFFIX="$(date +%s)"
A_EMAIL="alice-${SUFFIX}@example.com"
B_EMAIL="bob-${SUFFIX}@example.com"
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

UUID() { python3 -c 'import uuid;print(uuid.uuid4())'; }

MSG1=$(UUID)
echo "→ A send #1"
curl -sS -X POST "$BASE/messages" -H "Authorization: Bearer $TA" -H "Content-Type: application/json" \
  -d "{\"id\":\"$MSG1\",\"type\":0,\"content\":\"hello from A\"}" >/dev/null

echo "→ A idempotent retry (same id, different content) — server should return original"
RESP=$(curl -sS -X POST "$BASE/messages" -H "Authorization: Bearer $TA" -H "Content-Type: application/json" \
  -d "{\"id\":\"$MSG1\",\"type\":0,\"content\":\"DIFFERENT\"}" )
ECHO_CONTENT=$(echo "$RESP" | $PY "import sys,json;print(json.load(sys.stdin)['content'])")
test "$ECHO_CONTENT" = "hello from A" || { echo "FAIL: idempotency"; exit 1; }

MSG2=$(UUID)
echo "→ B send"
curl -sS -X POST "$BASE/messages" -H "Authorization: Bearer $TB" -H "Content-Type: application/json" \
  -d "{\"id\":\"$MSG2\",\"type\":0,\"content\":\"hello from B\"}" >/dev/null

echo "→ A history"
COUNT=$(curl -sS "$BASE/messages?take=10" -H "Authorization: Bearer $TA" | $PY "import sys,json;print(len(json.load(sys.stdin)))")
test "$COUNT" -ge "2" || { echo "FAIL: expected ≥2 messages, got $COUNT"; exit 1; }

echo "→ A mark B's message as read"
curl -sS -X POST "$BASE/messages/$MSG2/read" -H "Authorization: Bearer $TA" -o /dev/null -w "HTTP %{http_code}\n"

echo "✓ Chat REST smoke geçti."
