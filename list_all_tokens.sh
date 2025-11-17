#!/bin/bash

set -euo pipefail

source .env

FACTORY="0x1c5e0de229e6bf092A84fC22bb371ff08f1aCbc2"

echo "════════════════════════════════════════"
echo "📋 생성된 IP 토큰 목록"
echo "════════════════════════════════════════"
echo ""

# 토큰 개수
COUNT_HEX=$(cast call $FACTORY "getTokenCount()" --rpc-url $BESU_RPC_URL)
COUNT=$((16#${COUNT_HEX#0x}))

echo "총 $COUNT개 토큰 생성됨"
echo ""

if [ $COUNT -eq 0 ]; then
    echo "생성된 토큰이 없습니다."
    exit 0
fi

# 각 토큰 정보
for ((i=0; i<$COUNT; i++)); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "토큰 #$i:"
    echo ""
    
    # 토큰 데이터 조회
    TOKEN_DATA=$(cast call $FACTORY "tokens(uint256)" $i --rpc-url $BESU_RPC_URL)
    
    # 파싱 (name은 첫 번째 필드, 하지만 복잡함...)
    # 간단하게 주소만 추출
    echo "  원시 데이터:"
    echo "  $TOKEN_DATA"
    echo ""
done

echo "════════════════════════════════════════"
