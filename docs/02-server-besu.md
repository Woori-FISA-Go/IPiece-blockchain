<!-- docs/02-server-besu.md -->

# 02. 인프라 – Besu 노드 구성 및 운영

IPiece의 온체인 네트워크는 **온프레미스 vSphere 환경** 위에 구성된  
**Hyperledger Besu IBFT2 프라이빗 체인**이다.

- Validator 노드 4대
- RPC 노드 2대 (Active-Standby, VIP로 이중화)
- 배포/운영 서버 1대 (Foundry/스크립트 실행)

---

## 1. 노드 구성 개요

### 1.1 노드 역할

- Validator
  - 블록 생성/검증
  - RPC는 기본적으로 비활성화
  - 필요 시 디버깅용 RPC를 잠깐 열 수 있도록 별도 실행 옵션 준비
- RPC
  - 외부(백엔드)에서 접근하는 진입점
  - --rpc-http-enabled / --rpc-http-api 등 설정
  - keepalived 를 통해 VIP(예: 172.16.4.60) 로 이중화

### 1.2 디렉터리 구조 (노드 내부)

- /opt/besu/genesis.json 또는 /etc/besu/genesis.json  
  → 체인 설정(genesis, IBFT2 설정 등)
- /var/lib/besu  
  → 체인 데이터, 키스토어, static-nodes.json 등

---

## 2. Validator 노드 실행

### 2.1 기본 실행 (RPC 비활성화)

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
      --p2p-host=172.16.4.67

- --p2p-host에는 해당 노드의 실제 IP를 넣는다.
- --min-gas-price=0  
  → 프라이빗 체인이므로 gasPrice=0 트랜잭션 허용.

### 2.2 디버깅용 RPC 허용 (임시)

운영 중 Validator 노드에서 RPC를 잠깐 열어야 할 때 사용하는 모드.

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

- 운영에서는 가능한 한 Validator RPC는 닫아 두고,  
  디버깅 시에만 잠깐 띄운 뒤 종료하는 것을 원칙으로 한다.

---

## 3. RPC 노드 실행

### 3.1 기존 컨테이너 정리

    sudo docker stop besu 2>/dev/null || true
    sudo docker rm besu 2>/dev/null || true

### 3.2 새로 실행 (예: max-active-connections=1000)

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
      --host-allowlist=127.0.0.1,172.16.4.33,172.16.4.60,172.16.4.65,172.16.4.64,172.16.4.66 \
      --sync-mode=FULL \
      --min-gas-price=0 \
      --nat-method=NONE \
      --p2p-host=172.16.4.65

- --entrypoint /opt/besu/bin/besu  
  → 컨테이너 기본 엔트리포인트를 명시적으로 Besu 바이너리로 지정.
- --host-allowlist  
  → 허용할 클라이언트 IP들(백엔드 서버, VIP 등)을 설정.
- 각 RPC 노드별로 --p2p-host IP만 변경해서 실행.

---

## 4. RPC VIP & 이중화 구조

- RPC 노드 2대 (예: RPC1: 172.16.4.65, RPC2: 172.16.4.66)
- keepalived 를 사용해 VIP 172.16.4.60 부여
- 백엔드는 항상 http://172.16.4.60:8545 로만 접속

### 4.1 헬스체크 예시

- keepalived 의 track_script 에서
  - curl -s http://127.0.0.1:8545 로 eth_blockNumber 호출
  - 응답 실패 시 해당 노드에서 VIP를 내려 반대편 노드로 페일오버

### 4.2 이중화 테스트 시나리오

1. RPC1에서 docker stop besu
2. 백엔드에서 RPC 호출을 반복하면서
   - 잠시 타임아웃
   - 이후 RPC2로 VIP가 넘어가면 다시 정상응답
3. ip addr 로 VIP가 실제로 이동했는지 확인

---

## 5. 운영 점검 체크리스트

### 5.1 빠른 체인 상태 점검 스크립트 예시

    #!/usr/bin/env bash
    # quick-check.sh
    
    docker ps --filter name=besu
    
    ss -lntu | egrep '30303|8545|9545' || true
    
    echo "---- RECENT LOG ----"
    docker logs --tail=20 besu | egrep -i 'Listening|Peer|Imported|Block|ERROR|WARN' || true
    
    echo "---- STATIC NODES ----"
    sed -n '1,60p' /var/lib/besu/static-nodes.json 2>/dev/null || true
    
    echo "---- TIME SYNC ----"
    chronyc tracking | sed -n '1,6p'

### 5.2 RPC 레벨 확인

    curl -s http://localhost:8545 \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
    
    curl -s http://localhost:8545 \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

- blockNumber가 증가하는지
- peerCount가 0이 아닌지 확인

---

## 6. 트러블슈팅 정리

### 6.1 트랜잭션이 txpool에는 있는데 블록에 안 실리는 경우

- 증상
  - txpool_content 에는 pending 트랜잭션이 계속 존재
  - 블록 로그:
    - Imported block #N 0 tx, 3 pending 형태로 계속 반복
- 확인 포인트
  1. --min-gas-price 설정과 실제 트랜잭션 gasPrice 값
  2. Validator 노드들 간의 genesis.json / chainId 일치 여부
  3. 시간 동기화(chrony, ntp)
- 주요 원인
  - min-gas-price > 트랜잭션 gasPrice 인데, 프라이빗 체인에서 이를 의식하지 않고 0/1로 보내던 경우
  - 일부 Validator의 genesis가 다르거나, IBFT validator 집합이 꼬인 경우
- 대응
  - 프라이빗 체인에서는 --min-gas-price=0 으로 맞추고,  
    백엔드는 gasPrice=0 으로 트랜잭션 전송
  - 모든 노드의 genesis.json 재검증
  - 필요 시 테스트 환경에서 체인 재구성

### 6.2 Validator가 기동 실패 – keyPair 에러

- 로그 예시
  - Failed to start Besu: Supplied file does not contain valid keyPair pair.
- 원인
  - validator 키 파일 경로가 잘못되었거나
  - 권한/소유권 문제로 파일을 읽지 못하는 경우
- 대응
  - /var/lib/besu/key 또는 지정한 keystore 경로 확인
  - 파일 권한/소유자 조정 후 재기동

### 6.3 블록은 만들어지는데 RPC에서 응답이 없는 경우

- 확인
  - docker logs 에서 HTTP JSON-RPC 관련 에러
  - ss -lntu 로 8545 포트 listen 여부
  - --host-allowlist 에 백엔드 IP 포함 여부
- 원인
  - allowlist에 해당 클라이언트 IP 누락
  - 방화벽(pfSense 등)에서 포트 차단
- 조치
  - --host-allowlist 수정 후 재기동
  - 방화벽 Rule에서 RPC 포트(8545, 필요 시 9545) 허용

---

## 7. 체인 초기화/재시작 정책(요약)

- 운영/실제 데이터 환경
  - 원칙적으로 **체인을 날리지 않는다.**
  - DB를 초기화해야 한다면, 온체인 상태와의 정합성 이슈를 별도 설계해야 한다.
- 개발/테스트 환경
  - 필요 시 genesis부터 새로 구성해도 무방.
  - 단, 백엔드의 blockchain_tokens, blockchain_transactions 등도 함께 리셋해야 꼬이지 않는다.
