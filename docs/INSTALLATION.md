# 설치 가이드

## 환경 요구사항

- Ubuntu 24.04 LTS
- Docker 24.0+
- 250GB 스토리지 (RPC 노드)

## 네트워크 구성

### Validator 노드 (4개)
- 172.16.4.67-70
- 24GB NVMe Pruning

### RPC 노드 (2개)
- 172.16.4.65-66
- 250GB HDD Archive

## 설치 단계

```bash
# 1. 저장소 클론
git clone https://github.com/Woori-FISA-Go/IPiece-blockchain.git

# 2. 디렉토리 이동
cd IPiece-blockchain/scripts

# 3. 배포 스크립트 실행
./deploy_simple_final.sh

# 4. 네트워크 상태 확인
./check_network.sh
```

## 트러블슈팅

문제 발생 시 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 문서를 참고하세요.
