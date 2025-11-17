# 운영 가이드

## 일일 점검

매일 네트워크 상태를 확인하여 노드들이 정상적으로 동작하는지 확인합니다.

```bash
cd ~/IPiece-blockchain/scripts
./check_network.sh
```

## 백업

정기적으로 Validator 노드의 키와 중요 설정 파일을 백업합니다. (백업 스크립트가 준비되면 추가 예정)

```bash
# ./backup.sh
```

## 용량 확인

RPC 노드의 디스크 사용량을 주기적으로 확인하여 용량 부족을 예방합니다.

```bash
# RPC 노드 1번 HDD 확인
ssh ubuntu@172.16.4.65 "df -h /mnt/besu-hdd"

# RPC 노드 2번 HDD 확인
ssh ubuntu@172.16.4.66 "df -h /mnt/besu-hdd"
```

## 블록 동기화 확인

RPC 노드에 API 요청을 보내 최신 블록 번호를 확인하여 동기화 상태를 점검합니다.

```bash
curl -X POST http://172.16.4.65:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

