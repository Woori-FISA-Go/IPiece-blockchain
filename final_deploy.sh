#!/bin/bash

source .env

echo "════════════════════════════════════════"
echo "🚀 최종 배포 (Gas Price 고정)"
echo "════════════════════════════════════════"
echo ""

echo "1️⃣ Foundry 캐시 및 빌드 아티팩트 강제 삭제..."
forge clean --root contracts
echo "   ✅ 완료"
echo ""

echo "2️⃣ foundry.toml 설정..."
sed -i 's/^# gas_price = .*/gas_price = 50000000000/' contracts/foundry.toml
sed -i 's/^gas_price = .*/gas_price = 50000000000/' contracts/foundry.toml
echo "   ✅ Gas Price: 50 gwei"
echo ""

echo "3️⃣ Nonce 확인..."
NONCE=$(cast nonce --rpc-url $BESU_RPC_URL $DEPLOYER_ADDRESS)
echo "   Confirmed: $NONCE"
echo ""

echo "4️⃣ 재컴파일..."
forge build --root contracts --force
if [ $? -ne 0 ]; then
    echo "   ❌ 컴파일 실패. 스크립트를 중단합니다."
    exit 1
fi
echo "   ✅ 완료"
echo ""

echo "5️⃣ 재배포..."
echo "════════════════════════════════════════"
echo ""

ADMIN_ADDRESS=$ADMIN_ADDRESS \
forge script contracts/script/Deploy.s.sol:DeployScript \
    --root contracts \
    --rpc-url $BESU_RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast \
    --legacy \
    --with-gas-price 50000000000

echo ""
echo "════════════════════════════════════════"
echo "✅ 배포 완료!"
echo "════════════════════════════════════════"

# 원래대로 돌려놓기
sed -i 's/^gas_price = .*/# gas_price = 50000000000/' contracts/foundry.toml