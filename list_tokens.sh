#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "📋 생성된 모든 토큰 목록"
echo "════════════════════════════════════════"
echo ""

# 토큰 개수
TOKEN_COUNT_HEX=$(cast call $TOKEN_FACTORY_CONTRACT_ADDRESS \
  "getTokenCount()" \
  --rpc-url $BESU_RPC_URL)
TOKEN_COUNT_DEC=$((16#${TOKEN_COUNT_HEX#0x}))

echo "총 토큰 개수: $TOKEN_COUNT_DEC"
echo ""

if [ $TOKEN_COUNT_DEC -eq 0 ]; then
    echo "생성된 토큰이 없습니다."
    exit 0
fi

# 각 토큰 정보
for i in $(seq 0 $((TOKEN_COUNT_DEC - 1))); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "토큰 #$((i + 1))"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 토큰 정보 가져오기 (name, symbol, tokenAddress, dividendAddress, createdAt)
    TOKEN_INFO=$(cast call $TOKEN_FACTORY_CONTRACT_ADDRESS \
      "tokens(uint256)" \
      $i \
      --rpc-url $BESU_RPC_URL)
    
    # 주소 추출 (string, string, address, address, uint256)
    # sed -n '3p'는 3번째 줄을 의미하며, 토큰 주소에 해당합니다.
    TOKEN_ADDRESS=$(echo "$TOKEN_INFO" | sed -n '3p' | sed 's/.*\([0-9a-fA-F]\\{40\\}\\) $/0x\\1/')
    DIVIDEND_ADDRESS=$(echo "$TOKEN_INFO" | sed -n '4p' | sed 's/.*\([0-9a-fA-F]\\{40\\}\\) $/0x\\1/')
    
    echo "토큰 주소:   $TOKEN_ADDRESS"
    echo "배당 주소:   $DIVIDEND_ADDRESS"
    
    # 토큰 상세 정보
    NAME_HEX=$(cast call $TOKEN_ADDRESS "name()" --rpc-url $BESU_RPC_URL 2>/dev/null)
    if [ -n "$NAME_HEX" ]; then
        echo "이름:        $(cast --to-ascii $NAME_HEX)"
        
        SYMBOL_HEX=$(cast call $TOKEN_ADDRESS "symbol()" --rpc-url $BESU_RPC_URL 2>/dev/null)
        echo "심볼:        $(cast --to-ascii $SYMBOL_HEX)"
        
        TOTAL_HEX=$(cast call $TOKEN_ADDRESS "totalSupply()" --rpc-url $BESU_RPC_URL 2>/dev/null)
        TOTAL_DEC=$((16#${TOTAL_HEX#0x}))
        echo "총 발행량:   $TOTAL_DEC tokens"
        
        OWNER_HEX=$(cast call $TOKEN_ADDRESS "owner()" --rpc-url $BESU_RPC_URL 2>/dev/null)
        echo "Owner:       0x$(echo $OWNER_HEX | cut -c 27-66)"
        
        BALANCE_HEX=$(cast call $TOKEN_ADDRESS "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL 2>/dev/null)
        BALANCE_DEC=$((16#${BALANCE_HEX#0x}))
        echo "내 잔고:     $BALANCE_DEC tokens"
    fi
    
    echo ""
done

echo "════════════════════════════════════════"
