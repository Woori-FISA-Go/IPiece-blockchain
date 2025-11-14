#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "💵 KRWT 발행 (Mint)"
echo "════════════════════════════════════════"
echo ""

read -p "KRWT를 받을 주소 (기본값: Admin 주소): " TO_ADDRESS
TO_ADDRESS=${TO_ADDRESS:-$ADMIN_ADDRESS}

read -p "발행할 수량 (KRWT 단위): " AMOUNT

echo ""
echo "발행 정보:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "받는 이: $TO_ADDRESS"
echo "수량:   $AMOUNT KRWT"
echo ""

read -p "발행하시겠습니까? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "취소되었습니다."
    exit 0
fi

echo ""
echo "발행 중..."

cast send $KRWT_CONTRACT_ADDRESS \
  "mint(address,uint256)" \
  $TO_ADDRESS \
  $AMOUNT \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000

echo ""
echo "✅ 발행 완료!"
echo ""
echo "════════════════════════════════════════"
