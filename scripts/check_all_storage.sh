#!/bin/bash

echo "════════════════════════════════════════════════════════"
echo "💾 전체 노드 저장 공간 현황"
echo "════════════════════════════════════════════════════════"
echo ""

NODES=("172.16.4.67" "172.16.4.68" "172.16.4.69" "172.16.4.70" "172.16.4.65" "172.16.4.66")
NAMES=("Validator1" "Validator2" "Validator3" "Validator4" "RPC1" "RPC2")

for i in "${!NODES[@]}"; do
  NODE=${NODES[$i]}
  NAME=${NAMES[$i]}
  
  echo "┌─────────────────────────────────────────────────────"
  echo "│ ${NAME} (${NODE})"
  echo "└─────────────────────────────────────────────────────"
  
  ssh ubuntu@$NODE << 'SSH'
    echo "📁 전체 디스크 목록:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "NAME|disk|part"
    echo ""
    
    echo "💿 루트 파일시스템 (/):"
    df -h / | tail -1
    echo ""
    
    echo "📦 Besu 데이터 크기:"
    if [ -d /var/lib/besu ]; then
      du -sh /var/lib/besu
    else
      echo "  (데이터 없음)"
    fi
    
    echo ""
    echo "🔍 추가 디스크 확인:"
    lsblk | grep -E "sdb|sdc|nvme0n2" || echo "  (추가 디스크 없음)"
    echo ""
SSH
  
  echo "════════════════════════════════════════════════════════"
  echo ""
done

echo ""
echo "✅ 전체 확인 완료!"
