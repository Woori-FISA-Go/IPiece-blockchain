#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "📤 토큰 전송"
echo "════════════════════════════════════════"
echo ""

# 토큰 주소
read -p "토큰 주소: " TOKEN
read -p "받는 주소: " TO_ADDRESS
read -p "전송량 (정수 입력): " AMOUNT

echo ""
echo "전송 정보:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "토큰:   $TOKEN"
echo "받는 이: $TO_ADDRESS"
echo "수량:   $AMOUNT tokens"
echo ""

read -p "전송하시겠습니까? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "취소되었습니다."
    exit 0
fi

echo ""
echo "전송 중..."

cast send $TOKEN \
  "transfer(address,uint256)" \
  $TO_ADDRESS \
  $AMOUNT \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000

echo ""
echo "✅ 전송 완료!"
echo ""
echo "════════════════════════════════════════"
