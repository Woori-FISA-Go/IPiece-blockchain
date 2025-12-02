# 02. 인프라

## 1. 인프라 개요 (vSphere 기반 온프레미스 프라이빗 블록체인)

IPiece 온체인 영역은 vSphere 기반 온프레미스 환경 위에 Hyperledger Besu IBFT2 프라이빗 체인으로 구성되어 있습니다. 검증자(Validator) 노드와 RPC 노드를 분리하고, RPC 노드는 `keepalived`를 이용해 Active-Standby 구조로 구성하여 가용성과 일관성을 확보합니다.

- **합의 알고리즘**: IBFT 2.0 (Proof-of-Authority)
- **클라이언트**: Hyperledger Besu (Docker 컨테이너로 실행)
- **노드 구성**
  - Validator: 4대 (val1 ~ val4)
  - RPC: 2대 (rpc1, rpc2, Active-Standby + VIP)
  - Tx Gateway: 1대 (백엔드에서 RPC로 접근하는 진입점)
- **주요 특징**
  - 온프레미스 vSphere 위 VM 구성
  - NVMe 디스크는 체인 데이터(`/var/lib/besu`), HDD는 로그(`/var/log/besu`)에 분리 배치
  - 시간 동기화를 위해 `chrony` 사용
  - 모든 Besu 프로세스는 Docker 컨테이너로 기동
  - RPC 노드에만 JSON-RPC(8545)를 열고, Validator는 기본적으로 RPC를 닫는 구조입니다.

---

## 2. 인프라 구축 과정

### 2.1 호스트 인벤토리

| 역할                  | 호스트네임 | IP            |
|-----------------------|-----------|--------------|
| Validator 1           | `val1`    | 172.16.4.67  |
| Validator 2           | `val2`    | 172.16.4.68  |
| Validator 3           | `val3`    | 172.16.4.69  |
| Validator 4           | `val4`    | 172.16.4.70  |
| RPC 1                 | `rpc1`    | 172.16.4.65  |
| RPC 2                 | `rpc2`    | 172.16.4.66  |
| Tx Gateway            | `txgw`    | 172.16.4.33  |
| RPC VIP(Active-Standby)| (없음)   | **172.16.4.60** |

> 실제 IP는 사설망이므로 보안상 민감 정보(키, 패스워드) 없이 구조만 공개합니다.

### 2.2 서버 스펙 및 디렉토리 구조

#### (1) VM 스펙

- **RPC 노드**
  - vCPU 3개
  - RAM 6GB
  - NVMe 56GB
  - HDD 150GB
- **Validator 노드**
  - vCPU 3개
  - RAM 4GB
  - NVMe 40GB
  - HDD 100GB

#### (2) 공통 디렉토리 구조

- **실행/운영 설정 경로**: `/etc/besu`
- **동작 데이터 경로(체인 데이터)**: `/var/lib/besu`
- **로그 경로**: `/var/log/besu`
- **제네시스/키/스크립트 작업 경로**: `/opt/ibft`

NVMe는 읽기/쓰기 IOPS가 중요한 **체인 데이터**용(`/var/lib/besu`)으로, HDD는 용량이 많이 필요한 **로그**(`/var/log/besu`) 용도로 사용합니다.

### 2.3 공통 서버 세팅

모든 노드(RPC, Validator 공통)에서 기본 OS 세팅을 동일하게 맞춥니다.

#### (1) 시간 동기화 (chrony)

IBFT 합의는 타임스탬프 기반이므로 노드 간 시간이 수 ms 수준으로 맞지 않으면 합의에 문제가 생길 수 있습니다.

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install chrony

chronyc tracking
```

- `stratum` 값이 1에 가까울수록 상위 타임 소스에 가까운 상태입니다.
- 모든 노드에서 `chronyc tracking`으로 오차 범위를 확인합니다.

#### (2) 공통 패키지 설치

```bash
sudo apt -y install docker.io jq openssh-server

# docker 그룹에 현재 사용자 추가
sudo usermod -aG docker $USER
newgrp docker

# Besu 설정 디렉토리 생성
sudo mkdir -p /etc/besu

# Besu Docker 이미지 미리 pull
docker pull hyperledger/besu:latest

# 템플릿 생성 전에 기존 데이터 제거
sudo rm -rf /var/lib/besu/*
```

- **Docker**: Besu 컨테이너 실행용입니다.
- **jq**: JSON-RPC 응답 파싱 및 헬스체크 스크립트에서 사용합니다.
- **openssh-server**: RPC에서 Validator로 파일 전송(SCP) 및 Ansible/SSH 접근을 위해 사용합니다.

### 2.4 저장공간 세팅

#### (1) 체인 데이터용 논리 볼륨(`/var/lib/besu`, NVMe)

```bash
sudo vgs

# 위에서 확인한 VG 이름 사용 (예: ubuntu-vg)
VG=ubuntu-vg

# /var/lib/besu 용 24GB 논리 볼륨 생성
sudo lvcreate -n lv_besu -L 24G $VG
sudo mkfs.ext4 /dev/$VG/lv_besu

# 마운트 및 fstab 등록
sudo mkdir -p /var/lib/besu
UUID=$(sudo blkid -s UUID -o value /dev/$VG/lv_besu)
echo "UUID=$UUID /var/lib/besu ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
sudo mount -a

df -h /var/lib/besu
```

주의사항입니다.

- `VG` 이름을 잘못 지정하면 나중에 복구가 번거롭습니다.
- `fstab` 등록 후에는 반드시 `mount -a`로 부팅 시 마운트가 정상 동작하는지 확인합니다.

#### (2) 로그용 논리 볼륨(`/var/log/besu`, HDD)

```bash
# HDD 확인
lsblk

# 물리 볼륨 생성 및 기존 VG에 추가
sudo pvcreate /dev/sdb
sudo vgextend "$VG" /dev/sdb
sudo vgs

# 로그용 LV 생성
sudo lvcreate -n lv_log_besu -L 140G "$VG"
sudo mkfs.ext4 -F /dev/"$VG"/lv_log_besu

# 마운트 및 fstab 등록
sudo mkdir -p /var/log/besu
UUID=$(sudo blkid -s UUID -o value /dev/"$VG"/lv_log_besu)

# 기존 /var/log/besu 항목 제거 후 재등록
sudo sed -i '\|/var/log/besu|d' /etc/fstab
echo "UUID=$UUID  /var/log/besu  ext4  defaults,noatime,nodev,nosuid,noexec,nofail  0  2" | sudo tee -a /etc/fstab

sudo mount -a
findmnt -T /var/log/besu
df -h /var/log/besu
```

- 템플릿 복제 후 HDD 구성이 바뀌면 **UUID가 달라지므로 반드시 다시 마운트 설정**을 확인해야 합니다.
- LV 용량은 늘릴 수는 있지만 줄이기는 거의 불가능하므로 여유를 두고 설계합니다.

### 2.5 VM 템플릿 & 복제

1. 위 단계까지 공통 세팅(패키지, LVM, 디렉토리 구조)을 완료한 후 **베이스 템플릿 VM**을 생성합니다.
2. vSphere에서 템플릿을 기반으로 다음 VM을 생성합니다.
   - `rpc1`, `rpc2`
   - `val1`, `val2`, `val3`, `val4`
3. Validator는 향후 HDD 활용 계획에 따라 NVMe 위주로 템플릿을 만들고, 필요 시 추가 LVM 구성을 진행합니다.

이 과정을 통해 모든 노드의 OS/패키지/디스크 구조가 최대한 동일하게 유지되도록 합니다.

### 2.6 IBFT 제네시스 및 키 생성 (RPC1에서 작업)

RPC1에서 제네시스와 Validator 키를 생성하여 전체 체인의 초기 상태를 정의합니다.

#### (1) ibftConfig.json 생성

```bash
sudo mkdir -p /opt/ibft && sudo chown $USER:$USER /opt/ibft
cd /opt/ibft

cat > ibftConfig.json <<'JSON'
{
  "genesis": {
    "config": {
      "chainId": 20251029,
      "ibft2": {
        "blockperiodseconds": 2,
        "epochlength": 30000,
        "requesttimeoutseconds": 10
      }
    },
    "nonce": "0x0",
    "timestamp": "0x0",
    "gasLimit": "0x01C9C380",
    "difficulty": "0x1",
    "coinbase": "0x0000000000000000000000000000000000000000",
    "alloc": {}
  },
  "blockchain": { "nodes": { "generate": true, "count": 4 } }
}
JSON
```

- `chainId`: 이 네트워크를 식별하는 ID입니다. (프론트/백엔드의 RPC 설정과 반드시 일치해야 합니다.)
- `blockperiodseconds`: 목표 블록 생성 주기(여기서는 2초)입니다.
- `epochlength`: 에폭 길이(검증자 스냅샷 주기)입니다.
- `requesttimeoutseconds`: 현재 라운드에서 합의 실패로 다음 라운드로 넘어가기 전 대기 시간입니다.
- `gasLimit`: 블록당 가스 한도입니다. 프라이빗 체인이며 `min-gas-price=0` 설정을 사용하므로 충분히 크게 설정했습니다.
- `alloc`: 사전 잔액 할당용이지만, 가스비 0원 설계라 실제 사용하지 않습니다.
- `"count": 4`: 생성할 Validator 키 개수입니다.

#### (2) Besu operator로 genesis + 키 생성

```bash
cd /opt/ibft
docker run --rm -v "$PWD":/work -w /work hyperledger/besu:latest \
  operator generate-blockchain-config \
  --config-file=ibftConfig.json \
  --to=networkFiles \
  --private-key-file-name=key.priv \
  --genesis-file-name=genesis.json
```

생성 결과입니다.

- `/opt/ibft/networkFiles/genesis.json`: 모든 노드에서 공유하는 제네시스 파일입니다.
- `/opt/ibft/networkFiles/keys/0x...`: 각 Validator용 디렉토리
  - `key.priv`: IBFT 합의에 사용하는 노드 개인키
  - 파생된 주소(폴더명과 동일) → Validator 노드 식별에 사용

#### (3) 키 검증 스크립트

```bash
cd /opt/ibft/networkFiles

for d in keys/0x*; do
  [ -d "$d" ] || continue
  docker run --rm -v "$PWD":/work -w /work hyperledger/besu:latest \
    public-key export-address \
    --node-private-key-file="$d/key.priv" \
    --to="$d/derived.addr"
  echo "folder  = $(basename "$d")"
  echo "derived = $(cat "$d/derived.addr")"
  [ "$(basename "$d")" = "$(cat "$d/derived.addr")" ] && echo "[OK] 일치" || echo "[NG] 불일치"
  echo "-----
done
```

- 폴더명과 파생 주소가 모두 일치하는지 확인하여 키 파일 손상 여부를 체크합니다.

### 2.7 static-nodes.json 작성

RPC 및 Validator가 서로를 찾아갈 수 있도록 고정 피어 목록을 구성합니다.

```bash
cd /opt/ibft/networkFiles/keys

cat > /opt/ibft/static-nodes.json <<'JSON'
[
  "enode://<PUBKEY_VAL1>@172.16.4.67:30303",
  "enode://<PUBKEY_VAL2>@172.16.4.68:30303",
  "enode://<PUBKEY_VAL3>@172.16.4.69:30303",
  "enode://<PUBKEY_VAL4>@172.16.4.70:30303"
]
JSON
```

- `<PUBKEY_VALX>`에는 각 Validator의 **노드 공개키**를 넣습니다.
- enode URL이 잘못되면 피어 연결이 안 되고 블록이 생성되지 않으므로, 트러블슈팅 시 가장 먼저 확인해야 하는 부분입니다.

---

## 3. 블록체인 운영 방법

### 3.1 Validator 노드 운영 개요

- Validator는 IBFT 합의에 참여하는 노드이므로 보안이 중요합니다.
- 운영 원칙입니다.
  - **기본적으로 HTTP/WS RPC를 비활성화**합니다.
  - 필요할 때만 일시적으로 디버깅용 RPC 컨테이너를 별도 실행합니다.
  - `/etc/besu/key.priv` 퍼미션과 소유자(컨테이너 UID)에 특히 주의합니다.

### 3.2 RPC 노드 운영 개요

- RPC 노드는 사용자(백엔드) 트랜잭션이 몰리는 구간입니다.
- 운영 원칙입니다.
  - 외부에서 직접 Validator에 접근하지 않고, **모든 JSON-RPC는 RPC 노드를 통해서만** 접근합니다.
  - RPC 노드는 **VIP(172.16.4.60)** 로 서비스되며, 실제 물리 IP는 `rpc1`/`rpc2`가 번갈아가며 담당합니다.
  - 헬스체크 스크립트로 Besu 상태를 감시하고, 이상 시 자동으로 VIP를 넘깁니다.

---

## 4. 클라이언트 기동방식

아래는 **현재 사용 중인 기준 명령어**를 정리한 것입니다. (노드별 IP는 환경에 맞게 수정합니다.)

### 4.1 Validator 기본 기동 (RPC 비활성)

```bash
sudo docker run -d --name besu \
  --restart unless-stopped \
  --network host \
  -p 30303:30303/tcp -p 30303:30303/udp \
  -v /opt/besu/genesis.json:/opt/besu/genesis.json:ro \
  -v /var/lib/besu:/var/lib/besu \
  hyperledger/besu:latest \
  --data-path=/var/lib/besu \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30303 \
  --rpc-http-enabled=false \
  --rpc-ws-enabled=false \
  --host-allowlist=* \
  --sync-mode=FULL \
  --min-gas-price=0 \
  --nat-method=NONE \
  --p2p-host=172.16.4.67   # 각 Validator IP로 변경
```

- `--network host`를 사용하여 P2P 및 RPC 포트를 그대로 호스트에 바인딩합니다.
- 운영 시에는 RPC 비활성 상태로 두고, 디버깅이 필요할 때만 별도 컨테이너를 띄웁니다.

### 4.2 Validator 디버깅용 RPC 허용 (임시)

```bash
sudo docker run -d --name besu \
  --restart unless-stopped \
  --network host \
  -p 30303:30303/tcp -p 30303:30303/udp \
  -v /opt/besu/genesis.json:/opt/besu/genesis.json:ro \
  -v /var/lib/besu:/var/lib/besu \
  hyperledger/besu:latest \
  --data-path=/var/lib/besu \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30303 \
  --rpc-http-enabled=true \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8545 \
  --rpc-http-api=ADMIN,ETH,NET,WEB3,TXPOOL,DEBUG \
  --host-allowlist=* \
  --sync-mode=FULL \
  --min-gas-price=0 \
  --nat-method=NONE \
  --p2p-host=172.16.4.67
```

- 운영 환경에서는 **내부 관리망에서만 접근 가능하도록** 방화벽(UFW/pfSense)로 제한해야 합니다.
- 디버깅 후에는 컨테이너를 내려 RPC 노출을 해제합니다.

### 4.3 RPC 노드 기동

```bash
# 기존 컨테이너 정리
sudo docker stop besu 2>/dev/null || true
sudo docker rm besu 2>/dev/null || true

# RPC 노드 실행
sudo docker run -d --name besu \
  --restart unless-stopped \
  --network host \
  -p 30303:30303/tcp -p 30303:30303/udp \
  -p 8545:8545 -p 9545:9545 \
  -v /etc/besu/genesis.json:/opt/besu/genesis.json:ro \
  -v /var/lib/besu:/var/lib/besu \
  --entrypoint /opt/besu/bin/besu \
  hyperledger/besu:latest \
  --data-path=/var/lib/besu \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30303 \
  --rpc-http-enabled=true \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8545 \
  --rpc-http-api=ADMIN,ETH,NET,WEB3,TXPOOL,DEBUG \
  --rpc-http-max-active-connections=1000 \
  --rpc-http-cors-origins="*" \
  --host-allowlist=127.0.0.1,172.16.4.33,172.16.4.60,172.16.4.65,172.16.4.66 \
  --sync-mode=FULL \
  --min-gas-price=0 \
  --nat-method=NONE \
  --p2p-host=172.16.4.65   # rpc1/rpc2 각각 IP로 변경
```

- `--host-allowlist`에 Tx Gateway, RPC VIP 및 운영자가 접근하는 IP만 넣어둡니다.
- `--rpc-http-max-active-connections=1000`으로 동시 연결 수를 늘려, 트래픽 폭주 시에도 안정적으로 처리할 수 있도록 설정합니다.

---

## 5. 점검 가이드(체크리스트)

### 5.1 노드 로컬 상태 점검 스크립트 (Validator/RPC 공통)

```bash
# quick-check.sh
docker ps --filter name=besu
ss -lntu | egrep '30303' || true

echo "---- RECENT LOG ----"
docker logs --tail=5 besu | egrep -i 'Listening|Peer|Imported|Block|ERROR|WARN' || true

echo "---- STATIC NODES ----"
sed -n '1,60p' /var/lib/besu/static-nodes.json 2>/dev/null || true

echo "---- TIME ----"
chronyc tracking | sed -n '1,6p'
```

체크 포인트입니다.

- `docker ps`에서 컨테이너 상태가 `Up`인지 확인합니다.
- 로그에 `Imported new chain head` / `Block #...` 메시지가 주기적으로 찍히는지 확인합니다.
- `static-nodes.json`에 올바른 enode 목록이 있는지 확인합니다.
- `chronyc tracking`으로 시간 오차를 확인합니다.

### 5.2 RPC VIP 기준 체인 상태 점검

Tx Gateway 또는 관리용 PC에서 **VIP(172.16.4.60:8545)** 를 대상으로 점검합니다.

```bash
URL=http://172.16.4.60:8545
H='Content-Type: application/json'

# 1) 체인 ID / 네트워크 ID
curl -s -X POST "$URL" -H "$H" --data-raw \
'{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
curl -s -X POST "$URL" -H "$H" --data-raw \
'{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'

# 2) 동기화 상태 / 현재 블록
curl -s -X POST "$URL" -H "$H" --data-raw \
'{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
curl -s -X POST "$URL" -H "$H" --data-raw \
'{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 3) 피어 수
curl -s -X POST "$URL" -H "$H" --data-raw \
'{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# 4) 최신 블록 요약
curl -s -X POST "$URL" -H "$H" --data-raw \
'{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}'
```

- `eth_syncing` 결과가 `false` 여야 합니다.
- `eth_blockNumber` 값이 2초 간격으로 증가하는지 확인합니다.
- `net_peerCount`가 0이면 P2P 연결 문제를 의심해야 합니다.

---

## 6. RPC 이중화 방식 및 테스트

### 6.1 설계 개요

- **VRRP(keepalived)** 를 사용하여 `rpc1`, `rpc2` 사이에서 VIP(172.16.4.60)를 Active-Standby로 운영합니다.
- 자체 헬스체크 스크립트(`check_besu.sh`)를 통해 다음 조건을 만족하지 못하면 VIP를 포기합니다.
  - Besu 프로세스 존재
  - 피어 수 ≥ 1
  - 동기화 상태 (`eth_syncing == false`)
  - 일정 시간 내 블록 번호 증가

### 6.2 헬스체크 스크립트

두 RPC 노드 모두에 동일하게 배포하되, `/etc/default/besu-health` 에서 `PEERIP`만 다르게 설정합니다.

```bash
sudo apt -y install keepalived

echo 'export PEERIP=172.16.4.65' | sudo tee /etc/default/besu-health >/dev/null
# rpc2 에서는 172.16.4.66 등으로 조정

cat | sudo tee /usr/local/bin/check_besu.sh >/dev/null <<'SH'
#!/usr/bin/env bash
# Health (strong) + Last-Man-Standing
set -euo pipefail
. /etc/default/besu-health 2>/dev/null || true

RPC="${RPC:-http://127.0.0.1:8545}"
PRPC="${PRPC:-http://$PEERIP:8545}"
HDR='Content-Type: application/json'
PAUSE="${PAUSE:-2}"

call(){ curl -m 2 -s "$1" -H "$HDR" -d "$2"; }

# 로컬 검사
pgrep -f "hyperledger/besu" >/dev/null || LOCAL_OK=0
LOCAL_OK=1

# peers >= 1
PH=$(call "$RPC" '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  | jq -r '.result // empty' | sed 's/^0x//') || LOCAL_OK=0
[ -n "${PH:-}" ] || LOCAL_OK=0
[ $((16#$PH)) -ge 1 ] || LOCAL_OK=0

# not syncing
SYNC=$(call "$RPC" '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  | jq -r '.result') || LOCAL_OK=0
[ "$SYNC" = "false" ] || LOCAL_OK=0

# block increasing
B1=$(call "$RPC" '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | jq -r '.result // empty' | sed 's/^0x//') || LOCAL_OK=0
[ -n "${B1:-}" ] || LOCAL_OK=0
sleep "$PAUSE"
B2=$(call "$RPC" '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | jq -r '.result // empty' | sed 's/^0x//') || LOCAL_OK=0
[ -n "${B2:-}" ] || LOCAL_OK=0
[ $((16#$B2)) -ge $((16#$B1)) ] || LOCAL_OK=0

if [ "${LOCAL_OK:-0}" -eq 1 ]; then
  exit 0
fi

# 동료 상태 확인
PEER_OK=0
if [ -n "${PEERIP:-}" ]; then
  PH2=$(call "$PRPC" '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
    | jq -r '.result // empty' | sed 's/^0x//') || true
  if [ -n "${PH2:-}" ] && [ $((16#$PH2)) -ge 1 ]; then
    SY2=$(call "$PRPC" '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
      | jq -r '.result') || true
    if [ "$SY2" = "false" ]; then
      PEER_OK=1
    fi
  fi
fi

# 정책: 동료가 정상일 때만 VIP를 포기, 둘 다 이상하면 내가 붙잡음
if [ "$PEER_OK" -eq 1 ]; then
  exit 1
else
  exit 0
fi
SH

sudo chmod +x /usr/local/bin/check_besu.sh
```

### 6.3 keepalived 설정 (rpc1 = MASTER, rpc2 = BACKUP)

#### rpc1 (MASTER)

```bash
cat | sudo tee /etc/keepalived/keepalived.conf >/dev/null <<'CONF'
global_defs {
  script_user root;
  enable_script_security;
}

vrrp_script chk_besu {
  script "/usr/local/bin/check_besu.sh"
  interval 2
  fall 3
  rise 3
}

vrrp_instance VI_1 {
  state MASTER
  interface ens192
  virtual_router_id 51
  priority 110
  advert_int 1
  authentication { auth_type PASS; auth_pass 7b0b7b0b; }

  virtual_ipaddress {
    172.16.4.60/24 dev ens192
  }

  preempt_delay 5
  garp_master_delay 1
  garp_master_repeat 3
  garp_lower_prio_repeat 3

  track_script {
    chk_besu
    weight -20
  }
}
CONF

sudo chown root:root /usr/local/bin/check_besu.sh
sudo chmod 700 /usr/local/bin/check_besu.sh

sudo ufw allow from 172.16.4.66 comment 'VRRP peer rpc2'
sudo systemctl enable --now keepalived
```

#### rpc2 (BACKUP)

```bash
cat | sudo tee /etc/keepalived/keepalived.conf >/dev/null <<'CONF'
global_defs {
  script_user root;
  enable_script_security;
}

vrrp_script chk_besu {
  script "/usr/local/bin/check_besu.sh"
  interval 2
  fall 3
  rise 3
}

vrrp_instance VI_1 {
  state BACKUP
  interface ens192
  virtual_router_id 51
  priority 100
  advert_int 1
  authentication { auth_type PASS; auth_pass 7b0b7b0b; }

  virtual_ipaddress {
    172.16.4.60/24 dev ens192
  }

  # 필요 시 nopreempt 활성화 가능
  # nopreempt

  garp_master_delay 1
  garp_master_repeat 3
  garp_lower_prio_repeat 3

  track_script {
    chk_besu
    weight -20
  }
}
CONF

sudo chown root:root /usr/local/bin/check_besu.sh
sudo chmod 700 /usr/local/bin/check_besu.sh

sudo ufw allow from 172.16.4.65 comment 'VRRP peer rpc1'
sudo systemctl enable --now keepalived
```

### 6.4 페일오버 테스트

1. 정상 상태에서 VIP(172.16.4.60)가 `rpc1`의 인터페이스에 붙어있는지 확인합니다.
2. `rpc1`에서 Besu 컨테이너를 중지합니다.

   ```bash
   docker stop besu
   ```

3. `rpc2`의 `keepalived` 로그를 확인하면, 헬스체크가 `rpc1` 실패를 감지하고 VIP를 가져오는 메시지가 출력됩니다.
4. 네트워크에서 `ip addr` 로 확인하면, `rpc2`에 `172.16.4.60` 이 추가된 것을 확인할 수 있습니다.
5. 다시 `rpc1`에서 Besu를 정상 기동하면, 우선순위가 더 높은 `rpc1`이 VIP를 회수합니다.

---

## 7. 트러블슈팅 모음

### 7.1 Besu 컨테이너가 계속 재기동(healthy 대신 restarting/starting)

**증상**

- Docker 상태가 `Restarting`을 반복합니다.
- 로그에 `Supplied file does not contain valid keyPair` 등의 메시지가 보입니다.

**주요 원인 및 대응**

1. **Validator 키 파일 형식 오류**
   - `/etc/besu/key.priv`에 공백/개행/`0x` 접두어가 들어간 경우
   - 아래 스크립트로 키 형식을 검증합니다.

   ```bash
   sudo bash -c '
   set -o pipefail
   if [[ ! -f /etc/besu/key.priv ]]; then
     echo "MISSING: /etc/besu/key.priv"
     exit 1
   fi

   echo "== stat =="
   ls -l /etc/besu/key.priv || true

   echo "== visible line (sed -n l) =="
   sed -n "l" /etc/besu/key.priv || true

   RAW=$(cat /etc/besu/key.priv)
   CLEAN=$(echo -n "$RAW" | tr -d " \t\r\n" | sed -E "s/^0x//")
   echo "CLEAN=$CLEAN"
   echo "LEN=${#CLEAN}"
   if [[ "$CLEAN" =~ ^[0-9A-Fa-f]{64}$ ]]; then
     echo "[OK] 64-hex"
   else
     echo "[NG] not 64-hex"
   fi
   '
   ```

   - 길이가 64 바이트 16진수인지 확인하고, 맨 앞 `0x`는 제거합니다.

2. **키 파일 퍼미션/소유자 문제**

   - 컨테이너 내부 UID와 맞지 않아서 읽기 권한 에러가 발생할 수 있습니다.

   ```bash
   sudo chown 1000:1000 /etc/besu/key.priv
   sudo chmod 600 /etc/besu/key.priv
   ```

3. **`static-nodes.json` 및 enode URL 오타**

   - enode 주소를 잘못 입력하면 피어 연결이 안 되고, 블록이 생성되지 않습니다.
   - `quick-check.sh` 로그에서 피어 수와 블록 생성 여부를 함께 확인합니다.

### 7.2 블록이 생성되지 않거나 height가 멈춰 있을 때

체크 순서입니다.

1. **각 Validator에서 `quick-check.sh` 실행**
   - 피어 수가 0인 노드가 있는지 확인합니다.
   - 로그에 `ERROR` / `WARN` 메시지가 반복되는지 확인합니다.
2. **시간 동기화 확인**
   - `chronyc tracking`에서 offset이 비정상적으로 큰 노드가 있는지 확인합니다.
3. **제네시스 파일 불일치**
   - 모든 노드의 `/etc/besu/genesis.json`(또는 `/opt/besu/genesis.json`)이 동일한지 비교합니다.
   - 제네시스가 다르면 체인이 아예 다르기 때문에 block height가 서로 맞지 않습니다.

### 7.3 RPC에 접속은 되는데 체인 정보가 이상한 경우

- `eth_chainId` 및 `net_version` 이 기대하는 값과 다르면 **백엔드/프론트의 chainId 설정**과 네트워크가 어긋난 것입니다.
  - RPC URL, chainId, gasPrice 설정을 다시 맞추어야 합니다.
- `eth_syncing` 이 오래 동안 `true` 인 상태라면 Validator와 연결이 안 되었거나, 디스크/네트워크 이상을 의심해야 합니다.

### 7.4 UFW/방화벽 이슈

- RPC 노드에서는 다음 포트 정책을 확인합니다.
  - 30303/tcp, 30303/udp: 내부 P2P 통신용 (Validator/RPC 간)
  - 8545/tcp: **Tx Gateway(172.16.4.33)** 와 관리망에서만 접근 허용
  - VRRP 통신: 서로의 IP에서 VRRP 프로토콜 허용 (`keepalived` 설정 시 UFW 예외 추가)

```bash
sudo ufw allow 30303/tcp
sudo ufw allow 30303/udp
sudo ufw allow from 172.16.4.33 to any port 8545 proto tcp
sudo ufw allow from 172.16.4.65 comment 'VRRP peer rpc1'
sudo ufw allow from 172.16.4.66 comment 'VRRP peer rpc2'
```

### 7.5 기타 운영 팁

- 체인 파괴 수준의 장애(테스트 환경 초기화 등)가 아니면, Validator의 `/var/lib/besu` 를 함부로 지우지 않습니다.
- 새 노드를 추가할 때는
  - 동일한 제네시스 파일로 초기화하고
  - `static-nodes.json`에 추가
  - IBFT Validator 목록 관리(추가/제거)는 별도의 온체인 트랜잭션으로 처리해야 합니다.

---

이 문서는 IPiece 블록체인 인프라를 **다시 구축하거나 장애 발생 시 복구**할 때 참고할 수 있는 운영 가이드라인을 목표로 작성되었습니다. 실제 운영 환경에서는 보안 정책(방화벽, 키 관리, 접근제어 등)을 별도 문서로 정리하여 함께 관리하는 것을 전제로 합니다.
