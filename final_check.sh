#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "✅ 최종 확인"
echo "════════════════════════════════════════"
echo ""

# 1. 컨트랙트 주소
echo "1️⃣ 컨트랙트 주소"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KRWT:         $KRWT_CONTRACT_ADDRESS"
echo "TokenFactory: $TOKEN_FACTORY_CONTRACT_ADDRESS"
echo ""

# 2. Owner
echo "2️⃣ Owner 확인"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
KRWT_OWNER=$(cast call $KRWT_CONTRACT_ADDRESS "owner()" --rpc-url $BESU_RPC_URL | sed 's/^0x000000000000000000000000/0x/')
FACTORY_OWNER=$(cast call $TOKEN_FACTORY_CONTRACT_ADDRESS "owner()" --rpc-url $BESU_RPC_URL | sed 's/^0x000000000000000000000000/0x/')

echo "KRWT Owner:    $KRWT_OWNER"
echo "Factory Owner: $FACTORY_OWNER"
echo "Admin:         $ADMIN_ADDRESS"

if [ "$KRWT_OWNER" = "$ADMIN_ADDRESS" ] && [ "$FACTORY_OWNER" = "$ADMIN_ADDRESS" ]; then
    echo "✅ 모든 Owner가 Admin입니다!"
else
    echo "❌ Owner 확인 필요!"
fi
echo ""

# 3. 블록체인 상태
echo "3️⃣ 블록체인 상태"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BLOCK=$(cast block-number --rpc-url $BESU_RPC_URL)
echo "현재 블록: $BLOCK"
echo ""

# 4. Admin 잔고
echo "4️⃣ Admin 잔고"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BALANCE=$(cast balance $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
ETH_BALANCE=$(cast --to-unit $BALANCE ether)
echo "ETH: $ETH_BALANCE"
echo ""

echo "════════════════════════════════════════"
echo "🎉 재배포 성공!"
echo "════════════════════════════════════════"
