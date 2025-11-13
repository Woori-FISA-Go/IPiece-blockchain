#!/bin/bash

source .env

if [ -z "$1" ]; then
    echo "사용법: ./token_info.sh <토큰_주소>"
    exit 1
fi

TOKEN="$1"

echo "════════════════════════════════════════"
echo "🔍 토큰 상세 정보"
echo "════════════════════════════════════════"
echo ""
echo "토큰 주소: $TOKEN"
echo ""

# 기본 정보
echo "📄 기본 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NAME_HEX=$(cast call $TOKEN "name()" --rpc-url $BESU_RPC_URL)
echo "이름:        $(cast --to-ascii $NAME_HEX)"

SYMBOL_HEX=$(cast call $TOKEN "symbol()" --rpc-url $BESU_RPC_URL)
echo "심볼:        $(cast --to-ascii $SYMBOL_HEX)"

DECIMALS_HEX=$(cast call $TOKEN "decimals()" --rpc-url $BESU_RPC_URL)
echo "소수점:      $((16#${DECIMALS_HEX#0x}))"

TOTAL_HEX=$(cast call $TOKEN "totalSupply()" --rpc-url $BESU_RPC_URL)
echo "총 발행량:   $((16#${TOTAL_HEX#0x})) tokens"
echo ""

# 소유권 정보
echo "👤 소유권 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
OWNER_HEX=$(cast call $TOKEN "owner()" --rpc-url $BESU_RPC_URL)
echo "Owner:       0x$(echo $OWNER_HEX | cut -c 27-66)"
echo ""

# 잔고 정보
echo "💰 잔고 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ADMIN_BAL_HEX=$(cast call $TOKEN "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
echo "Admin:       $((16#${ADMIN_BAL_HEX#0x})) tokens"

DEPLOYER_BAL_HEX=$(cast call $TOKEN "balanceOf(address)" $DEPLOYER_ADDRESS --rpc-url $BESU_RPC_URL)
echo "Deployer:    $((16#${DEPLOYER_BAL_HEX#0x})) tokens"
echo ""

# 화이트리스트 확인
echo "✅ 화이트리스트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ADMIN_WL_HEX=$(cast call $TOKEN "whitelist(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
ADMIN_WL_BOOL=$((16#${ADMIN_WL_HEX#0x}))
if [ $ADMIN_WL_BOOL -eq 1 ]; then
    echo "Admin:       ✅ 등록됨"
else
    echo "Admin:       ❌ 미등록"
fi

DEPLOYER_WL_HEX=$(cast call $TOKEN "whitelist(address)" $DEPLOYER_ADDRESS --rpc-url $BESU_RPC_URL)
DEPLOYER_WL_BOOL=$((16#${DEPLOYER_WL_HEX#0x}))
if [ $DEPLOYER_WL_BOOL -eq 1 ]; then
    echo "Deployer:    ✅ 등록됨"
else
    echo "Deployer:    ❌ 미등록"
fi
echo ""

echo "════════════════════════════════════════"
