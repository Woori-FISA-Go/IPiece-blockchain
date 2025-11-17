#!/bin/bash
set -euo pipefail

echo "════════════════════════════════════════════════════════"
echo "🚀 Besu Archive 최종 배포 (250GB HDD)"
echo "════════════════════════════════════════════════════════"
echo ""

# 설정값
RPCS=("172.16.4.65" "172.16.4.66")
BOOTNODES="enode://81ecbef2998b4678c28b2260a1dc9993599ae3e42ec1c34e34d9c7a94c21b282db47b74a65ee920b0003c3333787e689a95996601d5b3ea907e810808cb1f6b1@172.16.4.67:30303,enode://15acba8195ca7fc9775781594e133e751a40901728c5348ed0eb4cc67a1667dbac6e2daeb96d1e516d4d6861e46cf18817a8ce77b688f70af7f7fde0b336bf26@172.16.4.68:30303,enode://bb12f4da7155e52fc2aad6573bcfdc3818154ca7fa9517b3812c8cb7beac9cc9d75ee3d039ed32344b9866efbfe5d061c0d4264d660737089bd2d40d83282cb8@172.16.4.69:30303,enode://f0393069ad1630b0ecb0fda56809b8005502ec15dbe3b71bd84abdcec7c1425694ec19a74b69d73dfd8172a3f7f9635e1448ccc8288d409ff80ff8339010cd67@172.16.4.70:30303"

# 1️⃣ Besu 컨테이너 정리
echo "1️⃣ 기존 Besu 컨테이너 정리..."
for NODE in "${RPCS[@]}"; do
  ssh ubuntu@$NODE "docker stop besu 2>/dev/null || true" || true
  ssh ubuntu@$NODE "docker rm -f besu 2>/dev/null || true" || true
done
echo "✅ 정리 완료"
echo ""

# 2️⃣ 데이터 준비 (기존 데이터를 HDD로 복사)
echo "2️⃣ Besu 데이터 준비 (HDD로 복사)..."
for NODE in "${RPCS[@]}"; do
  ssh ubuntu@$NODE << 'SSH'
    # 기존 데이터가 있으면 HDD로 복사
    if [ -d /var/lib/besu ] && [ ! -L /var/lib/besu ]; then
      sudo rsync -av /var/lib/besu/ /mnt/besu-hdd/ 2>/dev/null || true
      sudo chown -R 1000:1000 /mnt/besu-hdd
    fi
SSH
done
echo "✅ 데이터 준비 완료"
echo ""

# 3️⃣ Archive 모드로 Besu 시작
echo "3️⃣ Archive 모드 Besu 시작..."
for NODE in "${RPCS[@]}"; do
  echo "  → $NODE 시작 중..."
  ssh ubuntu@$NODE << SSHEOF
    docker run -d --name besu \\
      --restart unless-stopped \\
      -p 30303:30303/tcp -p 30303:30303/udp \\
      -p 8545:8545 \\
      -v /opt/besu/genesis.json:/opt/besu/genesis.json:ro \\
      -v /mnt/besu-hdd:/var/lib/besu \\
      hyperledger/besu:latest \\
      --data-path=/var/lib/besu \\
      --genesis-file=/opt/besu/genesis.json \\
      --p2p-port=30303 \\
      --p2p-host=${NODE} \\
      --bootnodes=${BOOTNODES} \\
      --rpc-http-enabled \\
      --rpc-http-host=0.0.0.0 \\
      --rpc-http-port=8545 \\
      --rpc-http-api=ADMIN,NET,ETH,IBFT,WEB3,DEBUG,TRACE \\
      --host-allowlist="*" \\
      --sync-mode=FULL \\
      --data-storage-format=BONSAI
SSHEOF
done
echo "✅ Besu 시작 완료"
echo ""

# 4️⃣ 대기
echo "4️⃣ 블록 동기화 대기 중 (120초)..."
sleep 120
echo "✅ 대기 완료"
echo ""

# 5️⃣ 최종 확인
echo "5️⃣ 네트워크 상태 확인..."
./check_network.sh

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ 배포 완료!"
echo "════════════════════════════════════════════════════════"
