#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "💰 배당 분배"
echo "════════════════════════════════════════"
echo ""

read -p "배당 컨트랙트 주소: " DIVIDEND_CONTRACT
read -p "배당 총액 (KRWT 단위): " AMOUNT
read -p "배당받을 투자자 주소 목록 (쉼표로 구분): " INVESTORS_CSV

echo ""
echo "배당 정보:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "배당 컨트랙트: $DIVIDEND_CONTRACT"
echo "총액:         $AMOUNT KRWT"
echo "투자자 목록:   $INVESTORS_CSV"
echo ""

read -p "배당을 2단계에 걸쳐 진행합니다. 계속하시겠습니까? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "취소되었습니다."
    exit 0
fi

# cast send는 배열을 [addr1,addr2] 형식으로 받습니다.
INVESTORS_ARRAY="[$(echo $INVESTORS_CSV | sed 's/,/, /g')]"

# 1. KRWT Approve
echo ""
echo "1/2: KRWT Approve 중..."
cast send $KRWT_CONTRACT_ADDRESS \
  "approve(address,uint256)" \
  $DIVIDEND_CONTRACT \
  $AMOUNT \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000

echo "✅ Approve 완료."
echo ""
echo "⏳ 15초 대기 후 배당을 실행합니다..."
sleep 15

# 2. 배당 실행
echo ""
echo "2/2: 배당 실행 중..."
cast send $DIVIDEND_CONTRACT \
  "distributeDividend(uint256,address[])" \
  $AMOUNT \
  "$INVESTORS_ARRAY" \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000

echo ""
echo "✅ 배당 실행 완료!"
echo ""
echo "════════════════════════════════════════"

echo ""
echo "✅ 배당 실행 완료!"
echo ""
echo "════════════════════════════════════════"
