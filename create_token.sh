#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "🎨 토큰 생성"
echo "════════════════════════════════════════"
echo ""

# 토큰 정보 입력
read -p "토큰 이름: " TOKEN_NAME
read -p "토큰 기호 (예: NYO): " TOKEN_SYMBOL
read -p "발행량: " SUPPLY

echo ""
echo "생성 중..."
echo ""

# 토큰 생성 및 결과(JSON) 저장
RECEIPT_JSON=$(cast send $TOKEN_FACTORY_CONTRACT_ADDRESS \
  "createToken(string,string,uint256,address)" \
  "$TOKEN_NAME" \
  "$TOKEN_SYMBOL" \
  $SUPPLY \
  $ADMIN_ADDRESS \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000 --json)

# 사용자에게 전체 JSON 결과 출력
echo "$RECEIPT_JSON"
echo ""
echo "✅ 토큰 생성 완료!"
echo ""

# 변경된 TokenCreated 이벤트 시그니처 해시
TOKEN_CREATED_EVENT_HASH="0x10ecc469bceb60ca7784b04fd151339af890a3d8b4d90a0313d289f667d4fcd4"

# jq를 사용하여 JSON 결과에서 TokenCreated 이벤트 로그를 찾고, data 필드에서 주소들을 추출합니다.
# data layout: [string symbol offset, address tokenAddress, address dividendAddress, ...]
TOKEN_ADDRESS="0x$(echo "$RECEIPT_JSON" | jq -r ".logs[] | select(.topics[0] == \"$TOKEN_CREATED_EVENT_HASH\") | .data" | cut -c 91-130)"
DIVIDEND_ADDRESS="0x$(echo "$RECEIPT_JSON" | jq -r ".logs[] | select(.topics[0] == \"$TOKEN_CREATED_EVENT_HASH\") | .data" | cut -c 155-194)"

echo ""
echo "════════════════════════════════════════"
echo "🎉 완료!"
echo "════════════════════════════════════════"
echo ""
echo "추출된 주소:"
echo "  - 토큰 주소:   $TOKEN_ADDRESS"
echo "  - 배당 주소:   $DIVIDEND_ADDRESS"
echo ""
echo "메타마스크 설정 (토큰 가져오기):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. '토큰 가져오기' 클릭"
echo "2. 주소 입력: $TOKEN_ADDRESS"
echo "3. 기호: $TOKEN_SYMBOL"
echo "4. 소수점: 0"
echo ""
