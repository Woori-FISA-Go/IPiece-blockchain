#!/bin/bash

set -euo pipefail

source .env

echo "════════════════════════════════════════"
echo "🔍 재배포 상태 확인"
echo "════════════════════════════════════════"
echo ""

# 1. broadcast 폴더 확인
echo "1️⃣ broadcast 폴더 확인"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "contracts/broadcast/Deploy.s.sol/20251029" ]; then
    LATEST=$(ls -t contracts/broadcast/Deploy.s.sol/20251029/*.json | head -1)
    if [ -n "$LATEST" ]; then
        echo "최근 배포: $(basename $LATEST)"
        echo "시간: $(stat -c %y "$LATEST" 2>/dev/null || stat -f "%Sm" "$LATEST")"
    else
        echo "❌ 배포 기록 없음"
    fi
else
    echo "❌ broadcast 폴더 없음"
fi
echo ""

# 2. run-latest.json 확인
echo "2️⃣ 배포 내역 확인"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LATEST_RUN="contracts/broadcast/Deploy.s.sol/20251029/run-latest.json"
if [ -f "$LATEST_RUN" ]; then
    echo "✅ run-latest.json 발견!"
    echo ""
    
    # 배포된 컨트랙트 추출
    echo "배포된 컨트랙트:"
    cat "$LATEST_RUN" | jq -r '.transactions[] | select(.transactionType == "CREATE") | "  \(.contractName): \(.contractAddress)"'
    echo ""
    
    # 트랜잭션 상태
    echo "트랜잭션 상태:"
    cat "$LATEST_RUN" | jq -r '.receipts[] | "  TX: \(.transactionHash[0:10])... Status: \(.status)"'
else
    echo "❌ run-latest.json 없음"
fi
echo ""

# 3. 블록체인 상태
echo "3️⃣ 블록체인 상태"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BLOCK=$(cast block-number --rpc-url $BESU_RPC_URL)
echo "현재 블록: $BLOCK"

NONCE=$(cast nonce $DEPLOYER_ADDRESS --rpc-url $BESU_RPC_URL)
echo "Deployer Nonce: $NONCE"
echo ""

# 4. 기존 .env 주소 확인
echo "4️⃣ 현재 .env 설정"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KRWT:         $KRWT_CONTRACT_ADDRESS"
echo "TokenFactory: $TOKEN_FACTORY_CONTRACT_ADDRESS"
echo ""

# 5. 컨트랙트 존재 확인
echo "5️⃣ 컨트랙트 존재 확인"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "$KRWT_CONTRACT_ADDRESS" ]; then
    CODE=$(cast code $KRWT_CONTRACT_ADDRESS --rpc-url $BESU_RPC_URL)
    if [ "$CODE" != "0x" ]; then
        echo "✅ KRWT 존재"
    else
        echo "❌ KRWT 없음"
    fi
fi

if [ -n "$TOKEN_FACTORY_CONTRACT_ADDRESS" ]; then
    CODE=$(cast code $TOKEN_FACTORY_CONTRACT_ADDRESS --rpc-url $BESU_RPC_URL)
    if [ "$CODE" != "0x" ]; then
        echo "✅ TokenFactory 존재"
    else
        echo "❌ TokenFactory 없음"
    fi
fi
echo ""

echo "════════════════════════════════════════"
