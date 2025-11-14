#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "🎉 배당 결과 확인"
echo "════════════════════════════════════════"
echo ""

read -p "잔고를 확인할 투자자 주소: " INVESTOR_ADDRESS

if [ -z "$INVESTOR_ADDRESS" ]; then
    echo "주소가 입력되지 않았습니다."
    exit 1
fi

echo ""
echo "--- KRWT 잔고 조회 ---"

# 투자자 KRWT 잔고
INVESTOR_KRWT_HEX=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $INVESTOR_ADDRESS --rpc-url $BESU_RPC_URL)
echo "투자자 KRWT 잔고: $((16#${INVESTOR_KRWT_HEX#0x}))"

# Admin KRWT 잔고
ADMIN_KRWT_HEX=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
echo "Admin KRWT 잔고:  $((16#${ADMIN_KRWT_HEX#0x}))"

echo ""
echo "✅ 조회 완료!"
echo ""
echo "════════════════════════════════════════"
