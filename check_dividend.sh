#!/bin/bash

source .env

read -p "배당 컨트랙트 주소: " DIVIDEND
read -p "배당 총액: " AMOUNT

echo ""
echo "════════════════════════════════════════"
echo "🔍 배당 가능 여부 확인"
echo "════════════════════════════════════════"
echo ""

# SecurityToken 주소
TOKEN=$(cast call $DIVIDEND "securityToken()" --rpc-url $BESU_RPC_URL | sed 's/^0x000000000000000000000000/0x/')
echo "Token: $TOKEN"

# 총 발행량
TOTAL=$(cast call $TOKEN "totalSupply()" --rpc-url $BESU_RPC_URL)
TOTAL_DEC=$((16#${TOTAL#0x}))
echo "총 발행량: $TOTAL_DEC"

# 정책 확인
MIN_TOTAL=$(cast call $DIVIDEND "MIN_TOTAL_DIVIDEND()" --rpc-url $BESU_RPC_URL)
MIN_TOTAL_DEC=$((16#${MIN_TOTAL#0x}))
echo "최소 총 배당액: $MIN_TOTAL_DEC"

MIN_PER=$(cast call $DIVIDEND "MIN_PER_SHARE()" --rpc-url $BESU_RPC_URL)
MIN_PER_DEC=$((16#${MIN_PER#0x}))
echo "최소 1주당 배당: $MIN_PER_DEC"

echo ""
echo "계산:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PER_SHARE=$((AMOUNT / TOTAL_DEC))
echo "1주당 배당액: $PER_SHARE KRWT"
echo ""

# 검증
if [ $AMOUNT -lt $MIN_TOTAL_DEC ]; then
    echo "❌ 총 배당액이 너무 적습니다!"
    echo "   최소: $MIN_TOTAL_DEC KRWT"
elif [ $PER_SHARE -lt $MIN_PER_DEC ]; then
    echo "❌ 1주당 배당액이 너무 적습니다!"
    echo "   필요: $(($TOTAL_DEC * $MIN_PER_DEC + 1)) KRWT 이상"
else
    echo "✅ 배당 가능합니다!"
fi

echo ""
echo "════════════════════════════════════════"
