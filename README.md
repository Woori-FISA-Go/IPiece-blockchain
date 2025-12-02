# IPiece Blockchain

캐릭터 IP 기반 STO(Security Token Offering) 플랫폼 **IPiece**의 온체인 영역 레포

- 온프레미스 **Hyperledger Besu IBFT2** 네트워크
- **Spring Boot 백엔드 및 RDS(PostgreSQL)** 와 연동
- **스마트 컨트랙트** 빌드/테스트/배포 스크립트

---

## 문서 구조

- [01. 기획](docs/01-planning.md)
- [02. 인프라](docs/02-server-besu.md)
- [03. 스마트 컨트랙트](docs/03-contracts.md)
- [04. 백엔드 연동](docs/04-backend-integration.md)

---

## 문서별 개요

### 01. 기획

- 블록체인 기술스택
- IPiece 서비스 전체 중에서 **온체인(블록체인)의 역할** 
- 온체인과 오프체인 하이브리드 구조
- **체인에 기록** 하는 데이터와 **DB에서 관리**하는 데이터 비교
- 공모, 배당, 2차 거래 등 주요 비즈니스 플로우에서
  - 온체인이 “최종 원장”으로 어떻게 작동하는지 설명

### 02. 인프라

- vSphere 기반 온프레미스 환경에 블록체인 노드(Validator / RPC)를 구성해 프라이빗 블록체인 네트워크 인프라를 구축
  - 4 Validator, 2 RPC(이중화), 1 배포서버
- 인프라 구축 과정
- 블록체인 운영 방법
  - 클라이언트 기동방식
  - 점검 가이드(체크리스트)
- RPC 이중화 방식 및 테스트
- 트러블슈팅

### 03. 스마트 컨트랙트

- 컨트랙트 역할 정의
  - **KRWT**: 현금 토큰
  - **SecurityToken**: 종목(증권형 토큰)
  - **DividendDistributor**: KRWT 기반 배당 분배
  - **TokenFactory**: 위 토큰들을 일괄 생성하는 팩토리
- 배포 및 테스트 방법
- 트러블슈팅
  
### 04. 백엔드 연동

- **Spring Boot 백엔드와 Besu의 통신방식**
  - RPC URL, chainId, gasPrice, legacy 트랜잭션 정책
- 공모/배당 등 **비즈니스 플로우와 온체인 트랜잭션 연결 구조**
- 온체인 트랜잭션을 `blockchain_transactions`에 관리하는 규칙
- 트랜잭션 pending, 이벤트 파싱 실패 등 백엔드 쪽 트러블슈팅 포인트

---

## 실행 플로우 (전체 흐름)

1. **인프라**  
   (자세한 내용: [02. 인프라](docs/02-server-besu.md))
   - Validator 4대, RPC 2대에 `genesis.json` 배포
   - 각 노드에서 **Docker로 Besu 실행**
     - Validator: RPC 비활성화 기본, 필요 시 디버깅용 RPC 모드 사용
     - RPC: HTTP(8545) / WS(9545) 오픈, host-allowlist/CORS 설정
   - `RPC1`, `RPC2`에 `keepalived`를 설정해
     - **RPC VIP**로 서비스 노출

2. **스마트 컨트랙트 빌드 및 배포**  
   (자세한 내용: [03. 스마트 컨트랙트](docs/03-contracts.md))
   - 배포 서버에서 Foundry(Forge) 설치
   - `contracts/` 디렉터리에서
     - `forge build`, `forge test` 로 컨트랙트 검증
     - `forge script` 또는 `final_deploy.sh` 같은 배포 스크립트로
       - KRWT, TokenFactory, 기본 종목(SecurityToken+DividendDistributor) 등을
       - Besu 체인에 배포
   - 배포된 컨트랙트 주소들은 환경변수로 정리

3. **백엔드 연동**  
   (자세한 내용: [04. 백엔드 연동](docs/04-backend-integration.md))
   - Spring Boot 백엔드에 rpc-url, chain-id, 가스비용 설정
   - 백엔드가
     - 공모 상품 등록 시 → TokenFactory 호출 → `blockchain_tokens` 갱신
     - 공모 청약 시 → holdings/잔고 업데이트 + 온체인 transfer
     - 배당 시 → holdings 기준 계산 + 온체인 KRWT 전송
   - 온체인 트랜잭션을 `blockchain_transactions` 테이블에서 관리

4. **프론트/사용자 관점**
   - 사용자는 프론트를 통해 **백엔드 API**만 호출
   - 백엔드가 내부에서 RDS와 블록체인을 적절히 엮어서
     - 공모 참여, 보유 내역 조회, 배당 내역 조회 등 기능을 제공
