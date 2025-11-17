#!/bin/bash

set -euo pipefail

# .env 파일 로드
if [ ! -f .env ]; then
    echo "❌ .env 파일이 없습니다!"
    exit 1
fi

source .env

echo "════════════════════════════════════════"
echo "🚀 IPiece Smart Contract Deployment"
echo "════════════════════════════════════════"
echo ""

# 배포 정보 확인
echo "📋 배포 정보:"
echo "  네트워크:   $BESU_RPC_URL"
echo "  체인 ID:    $BESU_CHAIN_ID"
echo "  배포자:     $DEPLOYER_ADDRESS"
echo "  관리자:     $ADMIN_ADDRESS"
echo ""

# 확인
read -p "배포를 시작하시겠습니까? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "배포 취소됨"
    exit 0
fi

echo ""
echo "🔨 컴파일 중..."
forge build --root contracts

echo ""
echo "📡 배포 중 (Gas Price: 10 gwei)..."

# 환경 변수 설정 및 배포
ADMIN_ADDRESS=$ADMIN_ADDRESS \
forge script contracts/script/Deploy.s.sol:DeployScript \
    --root contracts \
    --rpc-url $BESU_RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast \
    --legacy \
    --gas-price 10000000000

# 배포 결과 저장
BROADCAST_DIR="contracts/broadcast/Deploy.s.sol/$BESU_CHAIN_ID"
if [ -d "$BROADCAST_DIR" ]; then
    LATEST_RUN=$(ls -t $BROADCAST_DIR/run-*.json | head -1)
    
    if [ -f "$LATEST_RUN" ]; then
        echo ""
        echo "📄 배포 결과 파싱 중..."
        
        KRWT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "KRWT") | .contractAddress' "$LATEST_RUN")
        FACTORY_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "TokenFactory") | .contractAddress' "$LATEST_RUN")
        
        # deployed.json 생성
        cat > deployed.json << EOF
{
  "network": "IPiece Private Network",
  "chainId": $BESU_CHAIN_ID,
  "rpcUrl": "$BESU_RPC_URL",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployer": "$DEPLOYER_ADDRESS",
  "admin": "$ADMIN_ADDRESS",
  "contracts": {
    "KRWT": "$KRWT_ADDRESS",
    "TokenFactory": "$FACTORY_ADDRESS"
  }
}
EOF
        
        echo ""
        echo "════════════════════════════════════════"
        echo "✅ 배포 완료!"
        echo "════════════════════════════════════════"
        echo ""
        echo "📋 배포된 컨트랙트:"
        echo "  KRWT:          $KRWT_ADDRESS"
        echo "  TokenFactory:  $FACTORY_ADDRESS"
        echo ""
        echo "👤 관리자:      $ADMIN_ADDRESS"
        echo ""
        echo "📄 배포 정보: deployed.json"
        echo "════════════════════════════════════════"
    fi
fi
