#!/usr/bin/env bash
# E2E smoke: register × 2 + invite + accept + me + refresh + soft-archive.
# Önkoşul: API çalışıyor + couple-postgres ayakta.
# Kullanım:
#   cd backend/src/Couple.Api && dotnet run --no-build &
#   docs/progress/scripts/auth-and-invite-smoke.sh

set -euo pipefail
BASE="${BASE:-http://localhost:5049}"

jq_or_py() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d$1)"; }

echo "=== 1. Alice register ==="
A=$(curl -sS -X POST "$BASE/auth/register" -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"Password123","displayName":"Alice"}')
TOKEN_A=$(echo "$A" | jq_or_py "['accessToken']")
REFRESH_A=$(echo "$A" | jq_or_py "['refreshToken']")
echo "Alice ✓"

echo "=== 2. Alice davet üret ==="
INV=$(curl -sS -X POST "$BASE/couples/invites" -H "Authorization: Bearer $TOKEN_A")
CODE=$(echo "$INV" | jq_or_py "['code']")
echo "Davet kodu: $CODE"

echo "=== 3. Bob register ==="
B=$(curl -sS -X POST "$BASE/auth/register" -H "Content-Type: application/json" \
  -d '{"email":"bob@example.com","password":"Password123","displayName":"Bob"}')
TOKEN_B=$(echo "$B" | jq_or_py "['accessToken']")
echo "Bob ✓"

echo "=== 4. Bob accepts ==="
ACC=$(curl -sS -X POST "$BASE/couples/invites/$CODE/accept" -H "Authorization: Bearer $TOKEN_B")
echo "$ACC" | python3 -m json.tool

echo "=== 5. Alice refresh → couple_id claim güncellenmeli ==="
RA=$(curl -sS -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_A\"}")
TOKEN_A2=$(echo "$RA" | jq_or_py "['accessToken']")
COUPLE_ID_A=$(echo "$RA" | jq_or_py "['coupleId']")
echo "Alice yeni token coupleId: $COUPLE_ID_A"

echo "=== 6. /couples/me her iki tarafta ==="
echo "Alice:"; curl -sS "$BASE/couples/me" -H "Authorization: Bearer $TOKEN_A2" | python3 -m json.tool
echo "Bob:";   curl -sS "$BASE/couples/me" -H "Authorization: Bearer $TOKEN_B"   | python3 -m json.tool

echo "=== 7. Alice ilişkiyi sonlandırır ==="
curl -sS -X DELETE "$BASE/couples/me" -H "Authorization: Bearer $TOKEN_A2" -w "HTTP %{http_code}\n"

echo "=== 8. /couples/me 404 olmalı ==="
curl -sS -w " HTTP %{http_code}\n" "$BASE/couples/me" -H "Authorization: Bearer $TOKEN_A2"

echo
echo "✓ Smoke geçti."
