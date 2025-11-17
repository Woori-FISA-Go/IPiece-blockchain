#!/bin/bash
set -euo pipefail

# ============================================
# 🧩 Besu 네트워크 검증 스크립트
# 목적: 네트워크 정상 동작 확인 (블록 증가, 합의, RPC)
# ============================================

NODES=("172.16.4.67" "172.16.4.68" "172.16.4.69" "172.16.4.70" "172.16.4.65" "172.16.4.66")

cyan="\033[1;36m"; green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; reset="\033[0m"
say() { echo -e "${cyan}💬 $1${reset}"; }
ok()  { echo -e "${green}✅ $1${reset}"; }
warn(){ echo -e "${yellow}⚠️  $1${reset}"; }
line() { echo -e "${yellow}--------------------------------------------${reset}"; }

line
say "🔬 네트워크 검증 시작"
line

PASSED=0
TOTAL=0

for NODE in "${NODES[@]}"; do
  TOTAL=$((TOTAL + 1))
  echo
  say "검증: $NODE"
  
  # 1️⃣ 컨테이너 상태
  if ! ssh ubuntu@"$NODE" "docker ps --filter 'name=besu' -q" 2>/dev/null | grep -q .; then
    echo "  ❌ 컨테이너 실행 안 됨"
    continue
  fi
  echo "  ✓ 컨테이너 실행 중"
  
  # 2️⃣ RPC 응답
  CHAIN=$(curl -s -X POST "http://$NODE:8545" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' 2>/dev/null | jq -r '.result' 2>/dev/null)
  
  if [[ "$CHAIN" == "null" || -z "$CHAIN" ]]; then
    echo "  ❌ RPC 응답 없음"
    continue
  fi
  echo "  ✓ RPC 정상 (chainId: $CHAIN)"
  
  # 3️⃣ 블록 증가 확인
  BLOCK1=$(curl -s -X POST "http://$NODE:8545" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r '.result' 2>/dev/null)
  
  sleep 3
  
  BLOCK2=$(curl -s -X POST "http://$NODE:8545" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r '.result' 2>/dev/null)
  
  if [ "$BLOCK1" != "$BLOCK2" ]; then
    echo "  ✓ 블록 증가 확인 ($BLOCK1 → $BLOCK2)"
  else
    warn "  블록 증가 없음 (현재: $BLOCK1)"
  fi
  
  # 4️⃣ 피어 연결
  PEERS=$(curl -s -X POST "http://$NODE:8545" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null | jq -r '.result' 2>/dev/null)
  
  if [[ "$PEERS" != "null" && "$PEERS" != "0x0" ]]; then
    echo "  ✓ Peer 연결 ($PEERS)"
    PASSED=$((PASSED + 1))
  else
    warn "  Peer 연결 없음"
  fi
done

line
echo
ok "검증 결과: $PASSED/$TOTAL 노드 정상 작동"
line
