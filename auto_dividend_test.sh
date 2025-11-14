#!/bin/bash

source .env

INVESTOR="0x661636826fc779294f3d0d9ea2d12b8e8c3e30ec"

echo "════════════════════════════════════════"
echo "🎨 완전 자동 배당 테스트"
echo "════════════════════════════════════════"
echo ""

# 1. KRWT 발행
echo "1️⃣ KRWT 발행..."
cast send $KRWT_CONTRACT_ADDRESS \
  "mint(address,uint256)" \
  $ADMIN_ADDRESS \
  10000000 \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000 > /dev/null 2>&1

echo "   ✅ 완료"

# 2. 토큰 생성
echo "2️⃣ 토큰 생성..."
cast send $TOKEN_FACTORY_CONTRACT_ADDRESS \
  "createToken(string,uint256,address)" \
  "AutoTest" \
  10000 \
  $ADMIN_ADDRESS \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000 > /dev/null 2>&1

TOKEN_COUNT=$(cast call $TOKEN_FACTORY_CONTRACT_ADDRESS "getTokenCount()" --rpc-url $BESU_RPC_URL)
TOKEN_INDEX=$(( $((16#${TOKEN_COUNT#0x})) - 1 ))
TOKEN_INFO=$(cast call $TOKEN_FACTORY_CONTRACT_ADDRESS "tokens(uint256)" $TOKEN_INDEX --rpc-url $BESU_RPC_URL)
TOKEN=$(echo "$TOKEN_INFO" | sed -n '2p' | sed 's/.*\([0-9a-fA-F]\{40\}\)$/0x\1/')
DIVIDEND=$(echo "$TOKEN_INFO" | sed -n '3p' | sed 's/.*\([0-9a-fA-F]\{40\}\)$/0x\1/')

echo "   Token: $TOKEN"
echo "   Dividend: $DIVIDEND"

# 3. 화이트리스트
echo "3️⃣ 화이트리스트 추가..."
cast send $TOKEN \
  "addToWhitelist(address)" \
  $INVESTOR \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000 > /dev/null 2>&1

echo "   ✅ 완료"

# 4. 토큰 전송
echo "4️⃣ 토큰 전송 (5000 → 투자자)..."
cast send $TOKEN \
  "transfer(address,uint256)" \
  $INVESTOR \
  5000 \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000 > /dev/null 2>&1

echo "   ✅ 완료"

# 5. KRWT Approve
echo "5️⃣ KRWT Approve..."
cast send $KRWT_CONTRACT_ADDRESS \
  "approve(address,uint256)" \
  $DIVIDEND \
  10000 \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000 > /dev/null 2>&1

echo "   ✅ 완료"

# 6. 배당 실행
echo "6️⃣ 배당 실행 (10000 KRWT)..."
cast send $DIVIDEND \
  "distributeDividend(uint256,address[])" \
  10000 \
  "[$ADMIN_ADDRESS,$INVESTOR]" \
  --rpc-url $BESU_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --legacy \
  --gas-price 50000000000

echo ""

# 7. 결과
echo "7️⃣ 결과"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ADMIN_KRWT=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
INVESTOR_KRWT=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $INVESTOR --rpc-url $BESU_RPC_URL)

echo "Admin KRWT:   $((16#${ADMIN_KRWT#0x}))"
echo "투자자 KRWT:  $((16#${INVESTOR_KRWT#0x}))"
echo ""

if [ $((16#${INVESTOR_KRWT#0x})) -ge 5000 ]; then
    echo "✅✅✅ 배당 성공!"
    echo "   예상: 5000 KRWT"
    echo "   실제: $((16#${INVESTOR_KRWT#0x})) KRWT"
else
    echo "❌ 배당 실패"
fi

echo ""
echo "════════════════════════════════════════"
