# 🚀 Besu STO Private Network

캐릭터 IP 기반 STO (Security Token Offering) 거래 플랫폼

## 📊 아키텍처

### Validator 노드 (4개)
- **172.16.4.67, 68, 69, 70**
- IBFT2 합의 알고리즘
- 24GB NVMe Pruning 모드
- 2초마다 블록 생성

### RPC 노드 (2개 - Archive)
- **172.16.4.65, 66**
- 250GB HDD Archive 모드
- VIP (172.16.4.60)로 Active-Active HA
- 규제 준수를 위한 완전한 이력 보관

### 배포 서버
- **172.16.4.64**
- Genesis 관리
- Validator 키 백업
- 배포 스크립트 관리

## 🛠️ 기술 스택

- **Blockchain**: Hyperledger Besu
- **Consensus**: IBFT2
- **Network**: Private Network
- **Storage**: Archive Mode (RPC), Pruning Mode (Validator)

## 📋 시작하기

### 사전 요구사항
- Ubuntu 24.04 LTS
- Docker & Docker Compose
- 250GB+ 스토리지 (RPC 노드)

### 설치
```bash
git clone https://github.com/Woori-FISA-Go/IPiece-blockchain.git
cd IPiece-blockchain
```

### 배포
```bash
cd scripts
./deploy_simple_final.sh
```

### 상태 확인
```bash
./scripts/check_network.sh
```

## 📖 문서

- [설치 가이드](docs/INSTALLATION.md)
- [운영 가이드](docs/OPERATIONS.md)
- [API 문서](docs/API.md)
- [트러블슈팅](docs/TROUBLESHOOTING.md)

## 👥 팀

- **Organization**: IPiece-blockchain
- **팀 규모**: 5명
- **프로젝트**: 캐릭터 IP STO 플랫폼

## 📞 문의

GitHub Issues 탭에서 문의해주세요.

## 📄 라이선스

MIT License