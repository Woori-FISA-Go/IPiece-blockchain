#!/bin/bash

source .env

if [ -z "$1" ]; then
    echo "사용법: ./token_info.sh <토큰_주소> [조회할_주소1] [조회할_주소2] ..."
    exit 1
fi

TOKEN="$1"
# 첫 번째 인자(토큰 주소)를 제외하고 나머지 인자들을 주소 목록으로 사용
shift
ADDRESSES_TO_CHECK=("$@")

echo "════════════════════════════════════════"
echo "🔍 토큰 상세 정보"
echo "════════════════════════════════════════"
echo ""
echo "토큰 주소: $TOKEN"
echo ""

# 기본 정보
echo "📄 기본 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NAME_HEX=$(cast call $TOKEN "name()" --rpc-url $BESU_RPC_URL 2>/dev/null)
echo "이름 (Hex):  $NAME_HEX"

SYMBOL_HEX=$(cast call $TOKEN "symbol()" --rpc-url $BESU_RPC_URL 2>/dev/null)
echo "심볼:        $(cast --to-ascii $SYMBOL_HEX)"

DECIMALS_HEX=$(cast call $TOKEN "decimals()" --rpc-url $BESU_RPC_URL 2>/dev/null)
echo "소수점:      $((16#${DECIMALS_HEX#0x}))"

TOTAL_HEX=$(cast call $TOKEN "totalSupply()" --rpc-url $BESU_RPC_URL 2>/dev/null)
echo "총 발행량:   $((16#${TOTAL_HEX#0x})) tokens"
echo ""

# 소유권 정보
echo "👤 소유권 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
OWNER_HEX=$(cast call $TOKEN "owner()" --rpc-url $BESU_RPC_URL 2>/dev/null)
echo "Owner:       0x$(echo $OWNER_HEX | cut -c 27-66)"
echo ""


# 인자로 주소가 넘어온 경우, 해당 주소들 정보 출력
if [ ${#ADDRESSES_TO_CHECK[@]} -gt 0 ]; then
    echo "👤 지정된 주소 정보"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for ADDR in "${ADDRESSES_TO_CHECK[@]}"; do
        BAL_HEX=$(cast call $TOKEN "balanceOf(address)" $ADDR --rpc-url $BESU_RPC_URL 2>/dev/null)
        BAL_DEC=$((16#${BAL_HEX#0x}))
        
        WL_HEX=$(cast call $TOKEN "whitelist(address)" $ADDR --rpc-url $BESU_RPC_URL 2>/dev/null)
        WL_BOOL=$((16#${WL_HEX#0x}))
        
        if [ $WL_BOOL -eq 1 ]; then
            WL_STATUS="✅ 등록됨"
        else
            WL_STATUS="❌ 미등록"
        fi
        
        echo "주소: $ADDR"
        echo "  - 잔고: $BAL_DEC tokens"
        echo "  - 화이트리스트: $WL_STATUS"
        echo ""
    done
else
    # 인자로 주소가 없는 경우, 기본(Admin, Deployer) 정보 출력
    echo "💰 기본 주소 잔고 정보"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ADMIN_BAL_HEX=$(cast call $TOKEN "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL 2>/dev/null)
    echo "Admin:       $((16#${ADMIN_BAL_HEX#0x})) tokens"

    DEPLOYER_BAL_HEX=$(cast call $TOKEN "balanceOf(address)" $DEPLOYER_ADDRESS --rpc-url $BESU_RPC_URL 2>/dev/null)
    echo "Deployer:    $((16#${DEPLOYER_BAL_HEX#0x})) tokens"
    echo ""

    echo "✅ 기본 주소 화이트리스트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ADMIN_WL_HEX=$(cast call $TOKEN "whitelist(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL 2>/dev/null)
    ADMIN_WL_BOOL=$((16#${ADMIN_WL_HEX#0x}))
    if [ $ADMIN_WL_BOOL -eq 1 ]; then
        echo "Admin:       ✅ 등록됨"
    else
        echo "Admin:       ❌ 미등록"
    fi

    DEPLOYER_WL_HEX=$(cast call $TOKEN "whitelist(address)" $DEPLOYER_ADDRESS --rpc-url $BESU_RPC_URL 2>/dev/null)
    DEPLOYER_WL_BOOL=$((16#${DEPLOYER_WL_HEX#0x}))
    if [ $DEPLOYER_WL_BOOL -eq 1 ]; then
        echo "Deployer:    ✅ 등록됨"
    else
        echo "Deployer:    ❌ 미등록"
    fi
    echo ""
fi

echo "════════════════════════════════════════"
