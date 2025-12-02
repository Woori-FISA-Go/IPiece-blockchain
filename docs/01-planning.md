# 01. 기획 – IPiece 온체인 설계 개요

캐릭터 IP 기반 STO(Security Token Offering) 플랫폼 **IPiece**에서  
이 레포는 **온체인(블록체인) 영역**을 담당한다.

- 온프레미스 **Hyperledger Besu IBFT2** 프라이빗 네트워크
- 현금 토큰(**KRWTV2**), 증권형 토큰(**SecurityTokenV2**), 배당 분배(**DividendDistributor**), 팩토리(**TokenFactory**)
- **Spring Boot 백엔드 + RDS(PostgreSQL)** 와의 하이브리드 구조

---

## 1. 블록체인 기술스택

### 1.1 프레임워크 & 체인

- **클라이언트**: Hyperledger Besu
- **합의 알고리즘**: IBFT2 (프라이빗/퍼미션드 BFT 합의)
- **네트워크**: vSphere 기반 온프레미스 프라이빗 체인
- **특징**
  - EVM 호환 (Solidity 컨트랙트 사용 가능)
  - 빠른 블록 타임(수 초 단위), 낮은 지연시간
  - 퍼블릭 체인이 아니라, **검증자 노드를 완전히 통제 가능한 환경**

### 1.2 스마트 컨트랙트 & 개발 도구

- **언어**: Solidity
- **툴체인**: Foundry
  - `forge build` – 컨트랙트 빌드
  - `forge test` – 단위 테스트
  - `forge script` – 배포 스크립트 실행
- **배포 스크립트**
  - `contracts/script/Deploy.s.sol`  
    → KRWTV2, TokenFactory, 예시 토큰/배당 컨트랙트를 한 번에 배포하는 스크립트

---

## 2. IPiece 전체 구조와 온체인의 역할

### 2.1 전체 구조 (개념도)

```text
[사용자/프론트]
       ↓ (HTTP)
[Spring Boot 백엔드] ──── RDS(PostgreSQL)
       ↓ (JSON-RPC)
[Besu RPC 노드] ─────── [Validator 노드 4대]  (IBFT2 합의)
       ↓
  [스마트 컨트랙트 상태]
