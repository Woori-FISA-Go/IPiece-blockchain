#!/bin/bash
set -euo pipefail

NODES=("172.16.4.67" "172.16.4.68" "172.16.4.69" "172.16.4.70" "172.16.4.65" "172.16.4.66")
RPC_PORT=8545

cyan="\033[1;36m"; green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; reset="\033[0m"
say() { echo -e "${cyan}💬 $1${reset}"; }
ok()  { echo -e "${green}✅ $1${reset}"; }
err() { echo -e "${red}❌ $1${reset}"; }
line() { echo -e "${yellow}--------------------------------------------${reset}"; }

line
say "🧩 Besu 네트워크 상태 확인"
line

HEALTHY=0
TOTAL=${#NODES[@]}

for NODE in "${NODES[@]}"; do
  echo
  say "$NODE 상태 확인..."
  
  # 1️⃣ Docker 컨테이너 상태 (마지막 줄만)
  CONTAINER=$(ssh ubuntu@"$NODE" "docker ps --filter 'name=besu' --format '{{.Status}}' | head -1" 2>/dev/null)
  
  if [ -z "$CONTAINER" ]; then
    err "  컨테이너 없음!"
    continue
  fi
  
  echo "  🐳 상태: $CONTAINER"
  
  # 2️⃣ RPC 연결 확인
  CHAIN_ID=$(curl -s -X POST "http://$NODE:$RPC_PORT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' 2>/dev/null | jq -r '.result // "error"' 2>/dev/null)
  
  if [[ "$CHAIN_ID" != "error" && -n "$CHAIN_ID" ]]; then
    echo "  🔗 RPC: OK"
    
    # 3️⃣ 블록 번호
    BLOCK=$(curl -s -X POST "http://$NODE:$RPC_PORT" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r '.result // "error"' 2>/dev/null)
    echo "  📦 블록: $BLOCK"
    
    # 4️⃣ 피어
    PEERS=$(curl -s -X POST "http://$NODE:$RPC_PORT" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null | jq -r '.result // "error"' 2>/dev/null)
    echo "  👥 피어: $PEERS"
    
    ok "$NODE 정상"
    HEALTHY=$((HEALTHY + 1))
  else
    err "  RPC 응답 없음"
  fi
done

line
echo
ok "네트워크 상태: $HEALTHY/$TOTAL 노드 정상"
line
