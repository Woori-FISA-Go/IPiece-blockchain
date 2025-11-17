#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "✅ 화이트리스트 관리"
echo "════════════════════════════════════════"
echo ""

read -p "토큰 주소: " TOKEN
read -p "추가할 주소: " ADDRESS

echo ""
echo "화이트리스트 추가:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "토큰:   $TOKEN"
echo "주소:   $ADDRESS"
echo ""

read -p "추가하시겠습니까? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "취소되었습니다."
    exit 0
fi

echo ""
echo "추가 중..."

cast send $TOKEN \
  "addToWhitelist(address)" \
  $ADDRESS \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000

echo ""
echo "✅ 화이트리스트 추가 완료!"
echo ""

# 확인
WL_HEX=$(cast call $TOKEN "whitelist(address)" $ADDRESS --rpc-url $BESU_RPC_URL)
WL_BOOL=$((16#${WL_HEX#0x}))
if [ $WL_BOOL -eq 1 ]; then
    echo "✅ 확인: $ADDRESS 가 화이트리스트에 등록되었습니다."
else
    echo "❌ 오류: 등록 확인 실패"
fi

echo ""
echo "════════════════════════════════════════"
