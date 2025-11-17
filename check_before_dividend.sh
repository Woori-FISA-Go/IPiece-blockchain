#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "🔍 배당 실행 전 필수 확인"
echo "════════════════════════════════════════"
echo ""

read -p "배당 컨트랙트 주소: " DIVIDEND
read -p "배당 총액 (KRWT): " AMOUNT

echo ""

# 1. SecurityToken 정보
TOKEN=$(cast call $DIVIDEND "securityToken()" --rpc-url $BESU_RPC_URL | sed 's/^0x000000000000000000000000/0x/')
echo "📊 토큰 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Token: $TOKEN"

# 2. 총 발행량
TOTAL=$(cast call $TOKEN "totalSupply()" --rpc-url $BESU_RPC_URL)
TOTAL_DEC=$((16#${TOTAL#0x}))
echo "총 발행량: $TOTAL_DEC"

# 3. 정책 확인
MIN_TOTAL=$(cast call $DIVIDEND "minTotalDividend()" --rpc-url $BESU_RPC_URL)
MIN_TOTAL_DEC=$((16#${MIN_TOTAL#0x}))
echo "최소 총 배당액: $MIN_TOTAL_DEC KRWT"

MIN_PER=$(cast call $DIVIDEND "minPerShare()" --rpc-url $BESU_RPC_URL)
MIN_PER_DEC=$((16#${MIN_PER#0x}))
echo "최소 1주당: $MIN_PER_DEC KRWT"
echo ""

# 4. 계산
echo "💰 배당 계산"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "배당 총액: $AMOUNT KRWT"
if [ $TOTAL_DEC -eq 0 ]; then
    PER_SHARE=0
else
    PER_SHARE=$((AMOUNT / TOTAL_DEC))
fi
echo "1주당: $PER_SHARE KRWT"
echo ""

# 5. 검증
echo "✅ 검증 결과"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PASS=true

if [ $AMOUNT -lt $MIN_TOTAL_DEC ]; then
    echo "❌ 총 배당액 부족!"
    echo "   최소: $MIN_TOTAL_DEC KRWT"
    echo "   현재: $AMOUNT KRWT"
    PASS=false
fi

if [ $MIN_PER_DEC -gt 0 ] && [ $PER_SHARE -lt $MIN_PER_DEC ]; then
    echo "❌ 1주당 배당액 부족!"
    echo "   최소: $MIN_PER_DEC KRWT"
    echo "   현재: $PER_SHARE KRWT"
    NEEDED=$((TOTAL_DEC * MIN_PER_DEC + 1))
    echo "   필요: $NEEDED KRWT 이상"
    PASS=false
fi

# 6. Admin KRWT 잔고
ADMIN_BAL=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
ADMIN_BAL_DEC=$((16#${ADMIN_BAL#0x}))

if [ $ADMIN_BAL_DEC -lt $AMOUNT ]; then
    echo "❌ Admin KRWT 잔고 부족!"
    echo "   필요: $AMOUNT KRWT"
    echo "   현재: $ADMIN_BAL_DEC KRWT"
    PASS=false
fi

if [ "$PASS" = true ]; then
    echo "✅ 모든 조건 충족! 배당 실행 가능!"
else
    echo ""
    echo "⚠️  배당 실행 불가! 위 조건들을 확인하세요."
fi

echo ""
echo "════════════════════════════════════════"
