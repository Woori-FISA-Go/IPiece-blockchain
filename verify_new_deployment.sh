#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "✅ 재배포 검증"
echo "════════════════════════════════════════"
echo ""

LATEST="contracts/broadcast/Deploy.s.sol/20251029/run-latest.json"

if [ ! -f "$LATEST" ]; then
    echo "❌ run-latest.json 없음!"
    exit 1
fi

# Receipt 개수 확인
RECEIPT_COUNT=$(cat "$LATEST" | jq '.receipts | length')
echo "Receipt 개수: $RECEIPT_COUNT"

if [ "$RECEIPT_COUNT" -eq 0 ]; then
    echo "❌ Receipt 없음! 배포 실패!"
    exit 1
fi

echo "✅ Receipt 존재! 배포 성공!"
echo ""

# 주소 추출
KRWT=$(cat "$LATEST" | jq -r '.transactions[] | select(.contractName == "KRWT" and .transactionType == "CREATE") | .contractAddress')
FACTORY=$(cat "$LATEST" | jq -r '.transactions[] | select(.contractName == "TokenFactory" and .transactionType == "CREATE") | .contractAddress')

echo "배포된 주소:"
echo "  KRWT:         $KRWT"
echo "  TokenFactory: $FACTORY"
echo ""

# 코드 확인
echo "코드 확인:"
KRWT_CODE=$(cast code $KRWT --rpc-url $BESU_RPC_URL)
FACTORY_CODE=$(cast code $FACTORY --rpc-url $BESU_RPC_URL)

if [ "$KRWT_CODE" != "0x" ]; then
    echo "  ✅ KRWT: 코드 존재 (${#KRWT_CODE} bytes)"
else
    echo "  ❌ KRWT: 코드 없음"
fi

if [ "$FACTORY_CODE" != "0x" ]; then
    echo "  ✅ TokenFactory: 코드 존재 (${#FACTORY_CODE} bytes)"
else
    echo "  ❌ TokenFactory: 코드 없음"
fi
echo ""

# Owner 확인
KRWT_OWNER=$(cast call $KRWT "owner()" --rpc-url $BESU_RPC_URL | sed 's/^0x000000000000000000000000/0x/')
FACTORY_OWNER=$(cast call $FACTORY "owner()" --rpc-url $BESU_RPC_URL | sed 's/^0x000000000000000000000000/0x/')

echo "Owner 확인:"
echo "  KRWT:    $KRWT_OWNER"
echo "  Factory: $FACTORY_OWNER"
echo "  Admin:   $ADMIN_ADDRESS"

if [ "$KRWT_OWNER" = "$ADMIN_ADDRESS" ] && [ "$FACTORY_OWNER" = "$ADMIN_ADDRESS" ]; then
    echo "  ✅ 모든 Owner = Admin!"
else
    echo "  ❌ Owner 불일치!"
fi
echo ""

echo "════════════════════════════════════════"
echo "🎉 배포 완료!"
echo ""
echo ".env 업데이트:"
echo "  KRWT_CONTRACT_ADDRESS=$KRWT"
echo "  TOKEN_FACTORY_CONTRACT_ADDRESS=$FACTORY"
