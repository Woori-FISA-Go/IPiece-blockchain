# RPC API 문서

## Endpoints

- **RPC 1**: `http://172.16.4.65:8545`
- **RPC 2**: `http://172.16.4.66:8545`
- **VIP (HA)**: `http://172.16.4.60:8545` (Active-Active 고가용성)

## 주요 메소드

### eth_blockNumber
현재 최신 블록의 높이(번호)를 조회합니다.

**요청 예시:**
```bash
curl -X POST http://172.16.4.65:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### eth_getBalance
특정 주소(계정)의 잔액(ETH)을 조회합니다.

**요청 예시:**
```bash
curl -X POST http://172.16.4.65:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["조회할_지갑_주소","latest"],"id":1}'
```

## Archive 모드 전용
RPC 노드는 Archive 모드로 운영되므로, 모든 과거 시점의 블록 데이터를 조회할 수 있습니다.

