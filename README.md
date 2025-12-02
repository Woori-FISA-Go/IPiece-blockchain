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

- 블록체인 **도입배경**
- IPiece 서비스 전체 중에서 **온체인(블록체인)의 역할** 
- 블록체인 기술스택
- 설계원칙
- 온체인과 오프체인 **하이브리드 구조** 
- **체인에 기록** 하는 데이터와 **DB에서 관리**하는 데이터 비교
- **"최종 원장"** 으로서 온체인의 동작

### 02. 인프라

- 인프라 개요(vSphere 기반 온프레미스 **프라이빗 블록체인**) 
- 인프라 구축 과정
- 블록체인 운영 방법
  - 클라이언트 기동방식
  - 점검 가이드(체크리스트)
- **RPC 이중화** 방식 및 테스트
- 트러블슈팅 모음

### 03. 스마트 컨트랙트

- 컨트랙트 아키텍처
- 컨트랙트 역할 정의
  - **KRWT**: 현금 토큰
  - **SecurityToken**: 종목(증권형 토큰)
  - **DividendDistributor**: KRWT 기반 배당 분배
  - **TokenFactory**: 위 토큰들을 일괄 생성하는 팩토리
- 이벤트 및 오프체인 연동 포인트 
- 배포 및 테스트 방법
- 트러블슈팅
  
### 04. 백엔드 연동

- **Spring Boot 백엔드와 Besu의 통신방식**
  - RPC URL, chainId, gasPrice, legacy 트랜잭션 정책
- 공모/배당 등 **비즈니스 플로우와 온체인 트랜잭션 연결 구조**
- 온체인 트랜잭션을 `blockchain_transactions`에 관리하는 규칙
- 트러블슈팅

---

## 실행 플로우 (전체 흐름)

1. **인프라**  
   (자세한 내용: [02. 인프라](docs/02-server-besu.md))
   - Validator 4대, RPC 2대에 `genesis.json` 배포
   - 각 노드에서 **Docker로 Besu 기동**
   - `RPC1`, `RPC2`에 `keepalived`구성 후 **RPC VIP** 하나로 외부 서비스에 노출

2. **스마트 컨트랙트 빌드 및 배포**  
   (자세한 내용: [03. 스마트 컨트랙트](docs/03-contracts.md))
   - 배포 서버에 Foundry(Forge) 설치
   - `contracts/` 디렉터리에서
     - `forge build`, `forge test` 로 컨트랙트 빌드 및 테스트
     - 스크립트로 KRWT, TokenFactory, SecurityToken 등을 체인에 배포
     - 배포된 컨트랙트 주소는 **환경변수**로 정리하여 백엔드와 공유

3. **백엔드 연동**  
   (자세한 내용: [04. 백엔드 연동](docs/04-backend-integration.md))
   - Spring Boot 백엔드에 rpc-url, chain-id 등 설정
   - 백엔드 비즈니스 로직에서 온체인 호출
   - 온체인 트랜잭션을 `blockchain_transactions` 테이블에서 관리

4. **프론트/사용자 관점**
   - 사용자는 프론트를 통해 **백엔드 API**만 호출
   - **백엔드**가 내부에서 RDS와 블록체인을 함께 사용
