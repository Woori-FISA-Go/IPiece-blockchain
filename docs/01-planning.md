# 01. 기획 – IPiece 온체인 설계 개요

**IPiece 캐릭터 IP STO 플랫폼**에서 블록체인(온체인)이 담당하는 역할과 RDS(PostgreSQL) 기반 백엔드(오프체인)와의 **하이브리드 구조**를 정리합니다.

코드는 다음 레포들을 기준으로 합니다.

- 온체인: `IPiece-blockchain` (Besu, Solidity 컨트랙트, Foundry 스크립트)
- 백엔드: `IPiece` (Spring Boot, Web3j, PostgreSQL)
- 프론트엔드: `IPiece-web` (Next.js, 백엔드 API 호출)

---

## 1. 블록체인 도입배경

### 1.1 IPiece 도메인 특성

IPiece는 **캐릭터 IP를 쪼개서 투자 가능한 증권형 토큰**으로 만드는 STO 플랫폼입니다.

- “상품(Product)” 하나가 **실제 캐릭터 IP**를 나타냅니다.
- 각 상품은
  - **공모(Primary Offering)** 로 처음 투자자를 모집하고
  - 이후 **2차 거래(Secondary Trading)** 를 통해 자유롭게 매매되며
  - **정기적인 배당(Dividends)** 을 통해 현금 흐름을 분배합니다.

### 1.2 블록체인 도입의 효과

전통 주식 인프라는 **중앙 예탁/결제기관의 데이터베이스**를 중심으로 운영됩니다.

이 구조에서 캐릭터 IP 같은 자산을 “수많은 투자자가 나눠 갖고, 2차 거래까지 자유롭게 하는” 요구사항을 넣으려면 다음과 같은 한계가 드러납니다.

- **자유도가 부족한 원장 구조**
  - 기존 시스템에 맞추기 위해 **별도 상품 코드, 프로세스, 정산 로직**을 계속 추가해야 합니다.

- **대사와 최종성의 비용**
  - “누가 무엇을 얼마나 가지고 있는지(원장)”을 기관마다 따로 들고 있기 때문에,
    - 거래가 발생하면 **기관 간 대사**를 통해 나중에야 확정(T+0~T+2 등)됩니다.
  - 실시간 차트나 잔고는 “정산 완료 전 상태”를 먼저 보여주고,
    - **법적·회계적 최종 상태**는 뒤늦게 확정되는 구조라,
    - 여러 자산·여러 기관이 동시에 참여하는 구조에선 운영 복잡도뿐만 아니라 비용이 상승합니다.

- **규칙 집행이 사람과 절차 중심**
  - 특정 투자자만 참여 가능한 공모, 락업, 전매제한, 일부 구간 거래정지 같은 규칙들은  
    - 증권 시스템에서 **일부를 자동으로 차단**하면서도,  
    - 여전히 **업무 매뉴얼, 운영자 승인, 사후 심사**에 의존합니다.
  - 특히 비전통자산(부동산·IP·미술품 등)이 늘어날수록  
    - **“규칙을 시스템마다 따로 구현하고 운영 매뉴얼로 보완”하는 방식**은
    - 변경/추가/예외 처리 때마다 개발·테스트·운영 부담이 커지고,
    - 사람과 절차에 기대는 구간에서 **휴먼 에러·통제 누락 리스크**가 커집니다.

IPiece는 이러한 문제를 해결하기 위해 **“증권 구조”**를
**블록체인이라는 기술 인프라 위에서 운영**하는 방식을 선택했습니다.

- **합의 네트워크를 통한 ‘원장’ 공유**
  - 온프레미스 프라이빗 체인(Hyperledger Besu IBFT2)을 구성하고,
  - 검증자 노드들이 합의해서 만든 블록체인 상태를
    - “누가 어떤 토큰을 얼마만큼 보유하고 있는지”에 대한 **공유 원장/최종 원장**으로 사용합니다.

- **비전통자산의 규칙을 코드로 강제**
  - 투자 가능 계정을 화이트리스트로 관리합니다.
  - 거래 제한을 **스마트컨트랙트 레벨에서 강제**합니다.

- **정산/소유권은 온체인, 매칭/차트는 오프체인 – 하이브리드 구조**
  - IPiece의 현재 구조는 **오프체인에서 먼저 체결(매칭) → 온체인에서 정산(소유권 이전)**입니다.
    - 매수·매도 호가, 주문, 체결 로그, 차트 등은 **오프체인 DB**에서 빠르게 처리하고,
    - 최종적으로 **권리와 잔고의 최종 상태**는 **온체인 원장**이 책임집니다.
---

## 2. IPiece 서비스 전체 중에서 온체인(블록체인)의 역할

온체인은 **“실제 자산의 이동과 권리 행사”** 만을 최소 단위로 담당하고,  
그 외의 대부분 로직은 백엔드 + RDS가 담당합니다.

### 2.1 역할 상세

1. **현금 토큰(KRWT) 원장**
   - 실제 원화 입금/출금과 1:1 대응하는 **KRWT** 토큰의 발행/소각/이체
   - 배당 재원도 KRWT로 관리

2. **증권형 토큰(SecurityTokenV2) 원장**
   - 각 상품(Product)에 대응하는 **증권 토큰**의 발행/이체/소각
   - “누가 몇 토큰을 가지고 있는가”에 대한 **최종 잔고**를 체인이 소유

3. **배당 처리(DividendDistributor)**
   - 기록일(record date) 당시의 투자자별 토큰 보유 수량을 기준으로,
   - 배당금(KRWT)을 각 투자자에게 분배하는 온체인 로직

4. **토큰 생성/관리(TokenFactory)**
   - 새로운 상품이 추가될 때,
     - 해당 상품의 SecurityTokenV2 + DividendDistributor를 **일괄 배포**
   - 배포된 컨트랙트 주소는 DB의 `blockchain_tokens` 와 연동

### 2.2 오프체인(백엔드 + RDS)의 역할

반대로 백엔드 + DB는:

- **사용자/계좌/인증/OTP/로그인** 등 전통적인 웹 서비스 영역,
- **공모 스케줄/상품 메타데이터/투자 신청 내역**,
- **2차 거래 주문/호가/체결/차트/관심목록/마이페이지**,
- **배당 선언(Dividends 엔티티), 배당 지급 스케줄링**,
- **온체인 트랜잭션 관리(blockchain_transactions)**

를 담당합니다.

프론트엔드는 오직 **백엔드 API만 호출**합니다.

---

## 3. 블록체인 기술스택

### 3.1 체인 & 합의

- **클라이언트**: Hyperledger Besu
- **합의 알고리즘**: IBFT2 (Proof-of-Authority 계열, 퍼미션드 네트워크에 적합)
- **네트워크 구성(온프레미스 vSphere)**
  - **Validator 노드 4대**: 블록 생성과 합의
  - **RPC 노드 2대**: 읽기/쓰기 RPC, keepalived로 VIP 노출(이중화)
  - **배포 서버 1대**: Foundry 설치, 컨트랙트 빌드/배포, cast 실행

- **운영 특성**
  - gasPrice: 실질적으로 0에 가깝게 운영
    - Besu에 `--min-gas-price=0` 옵션
  - 퍼블릭 인터넷과 단절된 내부망 프라이빗 체인
  - Docker 컨테이너로 Besu 구동

### 3.2 스마트 컨트랙트 & 툴체인

- **언어**: Solidity
- **툴체인**: Foundry(Forge)
  - `forge build` – 컴파일
  - `forge test` – 단위 테스트
  - `forge script` – 배포 스크립트 실행
- **주요 컨트랙트**
  - `KRWT.sol` – 현금 토큰(ERC20)
  - `SecurityTokenV2.sol` – 종목 토큰(ERC20 + Snapshot + 화이트리스트/Pause 기능)
  - `DividendDistributor.sol` – 배당 분배 로직
  - `TokenFactory.sol` – 위 컨트랙트들을 묶어서 배포하는 팩토리

### 3.3 백엔드 연동 기술

- **라이브러리**: Web3j (Java)
- **환경**
  - Spring Boot 애플리케이션에서
  - `Web3jConfig` 를 통해 `rpc-url`, `chainId`, `private key` 등을 주입
- **패턴**
  - 온체인 호출은 `blockchain` 패키지의 서비스들이 담당
    (`BlockchainService`, `BlockchainDividendService` 등)
  - 비즈니스 서비스(공모, 배당, 투자 등)는 이 서비스들을 주입 받아 사용

---

## 4. 설계원칙

### 4.1 최종 원장(Single Source of Truth) 원칙

- **토큰 잔고(현금 토큰 + 증권형 토큰)** 의 최종 값은 **체인**이 기준입니다.
- 어떤 이유로든 DB와 체인 사이에 불일치가 발생하면,
  - **체인 이벤트 로그를 기준**으로 DB를 재구성할 수 있어야 합니다.

### 4.2 하이브리드 구조 원칙

- **읽기/집계/검색/마이페이지/차트/호가** 등은 RDS에 최적화
- **실제 자산이 움직이는 최소 지점**에서만 온체인 트랜잭션 사용

> **“자산 이동은 온체인, 나머지 비즈니스는 오프체인”**

### 4.3 권한/역할(Authorization) 모델

권한 모델은 **컨트랙트 레벨**과 **백엔드 레벨**로 나뉩니다.

#### 4.3.1 컨트랙트 레벨

- 플랫폼 운영자(**관리자 지갑**)이 온체인 상의 권한을 가지고 있습니다.
- 주요 기능은 `onlyOwner` 또는 이에 준하는 제어자를 통해 제한:
  - KRWT: `mint`, `burn` 등 발행·소각 권한
  - SecurityTokenV2: `addToWhitelist`, `pause`, `unpause` 등
  - TokenFactory: 새로운 토큰/배당 컨트랙트 생성

#### 4.3.2 백엔드 레벨

- `Web3jConfig` 에서 **관리자 Private Key** 로부터 자격증명을 생성합니다.
- 블록체인 연동 서비스는 이 자격증명을 사용해 트랜잭션 서명합니다.

- **사용자 지갑**
  - `UserWalletService` 에서 각 사용자의 온체인 주소를 관리 (주소만 DB에 저장).
  - Private Key는 DB에 저장하지 않으며,
    - 현재 아키텍처에서는 **모든 온체인 트랜잭션은 관리자 지갑이 대리로 수행**하는 구조

### 4.4 운영/안정성 원칙

- **가스비 0 / 프라이빗 체인**
  - 개발/교육 목적과 잦은 트랜잭션 테스트를 위해 가스비를 사실상 0으로 설정
- **Validator / RPC 역할 분리**
  - Validator는 RPC를 기본 차단, RPC 노드는 읽기/쓰기 전용.

---

## 5. 온체인과 오프체인 하이브리드 구조

### 5.1 전체 구조 개요

- **사용자 브라우저**
  - Next.js 프론트엔드 (`IPiece-web`)
  - → **백엔드 REST API** 호출

- **백엔드 (Spring Boot)**
  - RDS(PostgreSQL)와 JPA로 대부분의 비즈니스 로직 운영
  - Blockchain 관련 패키지에서 Web3j를 통해 Besu RPC와 통신
  - 온체인 트랜잭션은 `blockchain_transactions` 엔티티로 관리

- **블록체인 (Besu)**
  - IBFT2 검증자 + RPC 노드
  - Solidity 컨트랙트들이 배포되어 있음
  - KRWT, SecurityTokenV2, DividendDistributor, TokenFactory

- **RDS(PostgreSQL)**
  - `users`, `product`, `product_offering_info`, `holdings`, `dividends`,  
    `order_book`, `blockchain_tokens`, `blockchain_transactions` 등
  - 온체인 상태를 투영하는 테이블과 오프체인 전용 도메인 테이블 공존

### 5.2 플로우 패턴 (일반적인 트랜잭션 처리 시나리오)

1. **사용자/관리자 행동**
   - 프론트에서 투자/배당/공모 등록 등 API 호출.

2. **백엔드 비즈니스 처리(오프체인)**
   - 먼저 RDS 기준으로 입력 유효성, 상태 체크, 도메인 규칙 적용.
   - 공모/투자/배당 엔티티 생성 및 관련 테이블 업데이트.

3. **온체인 트랜잭션 생성**
   - `BlockchainService` / `BlockchainDividendService` 등이
     - Web3j를 이용해 대응되는 컨트랙트 함수를 호출 (예: `SecurityTokenV2.transfer`).
   - 생성된 트랜잭션 해시를 `blockchain_transactions` 에 기록
     - `transactionType`, `status=PENDING`, `productId`, `walletId` 등과 함께 저장.

4. **결과 모니터링 & 반영**
   - 스케줄러(`BlockchainReceiptScheduler`)가 주기적으로 RPC에서 receipt 조회.
   - 성공 시: `status=SUCCESS`, 블록 번호/블록 해시/로그 등 업데이트.
   - 실패 시: `status=FAILED`, 오류 원인/메시지 작성 (가능한 경우).

5. **조회/마이페이지**
   - 프론트는 DB 기반 API로 마이페이지/보유내역/배당내역을 조회.

---

## 6. 체인에 기록하는 데이터 vs DB에서 관리하는 데이터

### 6.1 요약 테이블

| 영역 / 기능                     | 온체인(블록체인)                                                                 | 오프체인(DB, 백엔드)                                                                                   |
|--------------------------------|----------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| 사용자 계정/프로필             | 없음                                                                             | `users`, `user_profile` 등                                                                            |
| 사용자 지갑 주소               | 컨트랙트 입장에서는 단순 주소                                                   | `user_wallet` 엔티티로 주소 관리 (Private Key는 저장하지 않음)                                       |
| 원화 잔고 (KRWT)               | KRWT 컨트랙트의 `balanceOf(address)`                                            | `accounts`, `balance_krw`, KRWT 충전/사용 이력 등                                                    |
| 종목 토큰 잔고(SecurityToken)  | SecurityTokenV2의 `balanceOf(address)`, `totalSupply`                            | `holdings` 테이블 (상품별 보유 수량, 평균 단가, 평가액 등)                                          |
| 토큰 발행/소각/이체 이벤트      | `Transfer`, `Mint`, `Burn` 등 이벤트 로그                                       | `blockchain_transactions`, 투자/거래 이력 테이블                                                     |
| 공모 상품/프로젝트 정보        | 없음                                                                             | `product`, `product_offering_info`                                                                    |
| 공모 신청/배정 내역            | 토큰 최종 잔고는 체인에 반영되지만, 신청/배정 상세는 없음                        | `investments`, `holdings`, 공모 참여 이력                                                            |
| 2차 거래 주문/호가/체결        | 체인에는 “최종 이체 결과”만 남음                                                | `order_book`, `trades`, 시세/차트/호가창                                                              |
| 배당 선언 (언제, 얼마, 어떤 상품)| DividendDistributor에는 직접적 선언 정보가 제한적 또는 간접적 표현              | `dividends`, `dividend_payouts`에 선언/스케줄/총액/상태 관리                                         |
| 배당 지급 실제 KRWT 이동       | DividendDistributor 계약의 호출 & 이벤트                                         | `blockchain_transactions` + `dividend_payouts`                                                        |
| 감사/증빙용 원장               | 블록/트랜잭션/로그 전부                                                          | 각종 이력 테이블 + 체인 재구성 스크립트의 기초 데이터                                                |
| 운영/로그/에러 정보            | 없음                                                                             | Spring 로그, 에러 트래킹, `blockchain_transactions.status`, 트러블슈팅용 로그                         |

### 6.2 설계 의도

- 체인에 올리는 데이터는 **“금전/권리의 변화”에 직접적인 것들만**.
- DB에는
  - **비즈니스 상태** (예: 공모 상태, 배당 상태, 2차 거래 주문 상태),
  - **사용자 친화적인 정보** (한글 프로젝트명, 썸네일, 설명, 통계),
  - **운영 편의를 위한 메타데이터** 를 올립니다.

이렇게 분리함으로써:

- 온체인은 비교적 **단순하고 안정적인 프로토콜 레벨**을 유지하고,
- 오프체인은 서비스 상황에 맞게 **빠르게 기능을 추가/변경**할 수 있게 됩니다다.

---

## 7. “최종 원장”으로서 온체인의 동작

### 7.1 공모(Primary Offering) 플로우 관점

1. **상품/공모 등록 (오프체인)**
   - 관리자 백오피스에서 상품(Product)과 공모 정보 등록
   - `product`, `product_offering_info` 등 DB에 저장

2. **토큰 생성 (온체인)**
   - 백엔드가 `TokenFactory.createProductToken(...)` 호출
     - 새로운 `SecurityTokenV2` + `DividendDistributor` 생성
     - 초기 공급량 `totalSupply` 를 관리자 지갑에 할당
   - 이 트랜잭션은 `blockchain_transactions` 에 `type=TOKEN_CREATION` 등으로 기록
   - 생성된 컨트랙트 주소를 DB의 `blockchain_tokens` / 상품과 연결

3. **투자자 공모 참여**
   - 투자자는 프론트를 통해 공모 API 호출
   - 백엔드에서
     - 투자 가능 여부 / 한도 / 수량 체크 (RDS)
     - 공모 참여 내역/배정 로직 수행
   - 이후, 실제 토큰 배정을 위해
     - 관리자 지갑 → 투자자 지갑으로 SecurityTokenV2 `transfer` 온체인 호출
   - 결과 트랜잭션은 `blockchain_transactions` 에 `type=PRIMARY_SUBSCRIPTION` 으로 기록

4. **원장 관점**
   - 최종적으로 “누가 얼마의 토큰을 보유하는가”는
     - SecurityTokenV2 컨트랙트의 `balanceOf`가 진실이다.
   - `holdings` 테이블은 이 정보를 투영한 **캐시/가공 정보**.

### 7.2 배당(Dividend) 플로우 관점

1. **배당 선언 (오프체인)**
   - 관리자: recordDate, payoutDate, totalAmount(KRW) 입력
   - 백엔드는 `dividends`, `dividend_payouts` 엔티티를 생성
   - 이 시점에서는 아직 온체인 자산 이동이 없습니다.

2. **배당 재원 확보 (온체인)**
   - 관리자 지갑 → DividendDistributor 컨트랙트로 KRWT 전송
   - 해당 KRWT 이동은 온체인 `Transfer` 이벤트로 기록

3. **배당 분배 실행 (온체인)**
   - DividendDistributor의 분배 함수 호출:
     - recordDate 기준으로 각 투자자의 보유 수량에 비례해 KRWT 전송
   - 각 투자자에게 KRWT `transfer` 이벤트 발생
   - 이 호출 역시 `blockchain_transactions` 에 `type=DIVIDEND_DISTRIBUTION` 등으로 저장

4. **DB 반영**
   - 백엔드는 이 이벤트/트랜잭션을 기준으로 배당 지급 완료 여부, 실제 지급액 등을 `dividend_payouts` 에 기록

### 7.3 2차 거래(Secondary Trading) 플로우 관점

1. **주문/호가/체결 (오프체인 전용)**
   - 주문, 호가창, 체결, 시세/차트 등은 모두 RDS의 `order_book`/`trades` 계열 테이블이 담당
   - 체인에는 이 상세 정보가 전혀 올라가지 않습니다.

2. **체결 후 잔고 이동 (온체인)**
   - 매수자/매도자 간의 체결이 확정되면,
     - 관리자 지갑이 대리로 SecurityTokenV2 `transfer(from, to, amount)` 를 호출
   - 이 트랜잭션은 `blockchain_transactions` 에 `type=SECONDARY_TRADE_TRANSFER` 등으로 기록

3. **최종 잔고**
   - 특정 시점에 Token과 투자자 주소를 기준으로 `balanceOf` 를 조회하면,
     - 모든 1차/2차 거래의 결과가 반영된 **최종 보유 토큰 수량**이 나옵니다.

※참고:
- **[02. 인프라](02-server-besu.md)**
- **[03. 스마트 컨트랙트](03-contracts.md)**
- **[04. 백엔드 연동](04-backend-integration.md)**
