<!-- docs/01-planning.md -->

# 01. 기획 – IPiece 온체인 설계 개요

캐릭터 IP 기반 STO(Security Token Offering) 플랫폼 **IPiece**에서  
이 레포는 **온체인(블록체인) 영역**을 담당한다.

- 온프레미스 **Hyperledger Besu IBFT2** 프라이빗 네트워크
- **Spring Boot 백엔드 및 RDS(PostgreSQL)** 와 연동
- **스마트 컨트랙트** 빌드/테스트/배포 스크립트

---

## 1. 블록체인 기술스택

### 1.1 프레임워크 & 체인

- 클라이언트: Hyperledger Besu
- 합의 알고리즘: IBFT2 (BFT 계열, 퍼미션드 프라이빗 체인에 적합)
- 네트워크: vSphere 기반 온프레미스 프라이빗 체인
- 특징
  - EVM 호환 (Solidity 컨트랙트 사용)
  - 빠른 블록 타임(수 초 단위), 낮은 지연시간
  - 퍼블릭 체인이 아닌, **검증자/노드 구성이 완전히 통제**되는 환경

### 1.2 스마트 컨트랙트 & 개발 도구

- 언어: Solidity
- 툴체인: Foundry
  - forge build – 컨트랙트 빌드
  - forge test – 단위 테스트
  - forge script – 배포 스크립트 실행
- 배포 스크립트
  - contracts/script/Deploy.s.sol  
    → KRWTV2, TokenFactory, 예시 토큰/배당 컨트랙트를 한 번에 배포하는 스크립트

---

## 2. IPiece 전체 구조와 온체인의 역할

### 2.1 전체 구조 (개념도)

    [사용자/프론트]
           ↓ (HTTP)
    [Spring Boot 백엔드] ──── RDS(PostgreSQL)
           ↓ (JSON-RPC)
    [Besu RPC 노드] ─────── [Validator 노드 4대]  (IBFT2 합의)
           ↓
      [스마트 컨트랙트 상태]

- 프론트는 항상 **백엔드 API만 호출**하고, 블록체인/RPC에는 직접 접근하지 않는다.
- 백엔드는
  - DB(RDS)를 이용해 계좌/잔고/주문/배당 이력을 관리하고,
  - Besu RPC를 통해 **스마트 컨트랙트 호출**을 수행한다.
- 블록체인은
  - **토큰 발행/이체/배당 같은 핵심 자산 상태**를 영구 보존하는 “최종 원장(final ledger)” 역할을 한다.

### 2.2 온체인 역할 요약

1. 자산(토큰) 발행 원장
   - KRWTV2(현금 토큰)
   - SecurityTokenV2(각 캐릭터 IP 종목 토큰)
   - 총 발행량, 소각, 보유 수량 등
2. 배당 분배 원장
   - DividendDistributor를 통해  
     “어떤 종목에 대해, 얼마의 KRWT를 배당으로 분배했는지”가 온체인에 남는다.
3. 온체인 트랜잭션 증빙
   - 공모, 배당, (선택적으로) 2차 거래에 대한 트랜잭션 해시가 남고,
   - 백엔드에서는 이를 blockchain_transactions 테이블과 연동해서  
     **감사 추적(audit trail)**을 확보한다.

---

## 3. 온체인 / 오프체인 하이브리드 구조

### 3.1 온체인에 두는 것

- KRWTV2/종목 토큰의 잔액(balanceOf) 및 총 발행량(totalSupply)
- 배당 수행 내역
  - 배당용 KRWT가 어느 주소로 얼마나 전송되었는지
- 토큰 생성/관리와 관련된 이벤트 로그
  - TokenFactory에서 새 토큰/디스트리뷰터 생성 시 이벤트

### 3.2 오프체인(DB)에 두는 것

- 유저 계정, KYC, 권한
- 실명 계좌 / 가상계좌 / 입출금 히스토리
- 공모 정보, 공모청약 내역
- 2차 거래 주문/체결(order_book, trades)
- holdings 테이블
  - “사용자 A가 종목 X를 몇 개 보유” 같은 비즈니스 레벨 잔고
  - 온체인 balanceOf를 그대로 쓰지 않고,  
    입출금/체결/배당 등 비즈니스 규칙을 반영해서 관리

### 3.3 분리 기준

| 구분                | 온체인(블록체인)                          | 오프체인(DB, RDS)                                         |
|---------------------|-------------------------------------------|-----------------------------------------------------------|
| 사용자 식별         | 지갑 주소(address)                        | user_id, 주민번호, 이름 등                                |
| 원화/토큰 잔고      | 지갑별 balanceOf(KRWT/Token)              | holdings, balance_krw 등 비즈니스 레벨 잔고               |
| 주문/체결 정보      | (선택) 이벤트로 기록 가능                 | order_book, trade 테이블                                  |
| 배당 수행           | KRWT transfer, Distributor 호출           | dividend_declarations, dividend_payouts, 세금/원천징수 등 |
| 감사/로그           | 트랜잭션 로그 + 이벤트                    | blockchain_transactions, 배치 로그, API 로그              |

---

## 4. 비즈니스 플로우별 온체인 사용 방식

### 4.1 공모(1차 발행 시점)

- 온체인
  - TokenFactory를 통해
    - 종목 토큰(SecurityTokenV2)
    - 배당 디스트리뷰터(DividendDistributor)
    를 생성.
  - 초기 발행량은 보통 관리자(issuer) 지갑으로 배정.
- 오프체인
  - product, product_offering_info, blockchain_tokens 등에
    - product_id
    - contract_address
    - symbol, name, decimals
    - total_supply
    등을 기록.

### 4.2 공모 청약(사용자 참여)

1. 사용자가 프론트에서 공모 참여 수량을 입력
2. 백엔드
   - 사용자의 입금/충전 상태를 확인 (balance_krw 혹은 KRWT 보유량)
   - 공모 가능 수량/금액 검증
   - holdings, order/청약 관련 테이블 업데이트
3. 온체인
   - 관리자 지갑에서 투자자 지갑으로 종목 토큰을 transfer
   - 또는 TokenSale/TokenFactory 관련 함수 호출로 청약 처리
   - 트랜잭션 해시를 blockchain_transactions 로 저장

> 설계 상 온체인은 **최종적인 토큰 소유권 이동**을 책임지고,  
> 오프체인은 **누가 얼마를 청약했고, 어떤 로직으로 배정되었는지**를 관리한다.

### 4.3 배당

1. 관리자/운영자가 배당을 선언
   - DB의 dividend_declarations 에  
     record_date, payout_date, total_amount (전체 배당 금액) 기록
2. 배당 레코드 날짜(record_date)에 맞춰 holdings를 기준으로 배당 비율 계산
3. 온체인
   - 관리자 지갑에서 유저 지갑으로 KRWT 전송
   - 또는 DividendDistributor를 사용해 분배 수행
4. blockchain_transactions 에 배당 관련 트랜잭션 해시를 저장하고,  
   dividend_payouts 테이블에 개별 사용자의 배당 내역을 저장.

### 4.4 2차 거래 (Secondary Trading)

- 주문/체결 로직 자체는 오프체인(백엔드+DB)에서 처리:
  - order_book, trades 테이블로 호가/체결 관리
- 온체인은 크게 두 가지 방식 중 선택 가능:
  1. 입·출금형  
     - 거래소처럼, 사용자가 토큰을 “입금/출금”하는 시점에만  
       온체인 transfer를 발생
     - 내부 잔고 이동(매수/매도)은 DB에서만 처리
  2. 체결연계형  
     - 체결이 발생할 때마다 실제 지갑 간 토큰 transfer 호출

현재 IPiece 초기 버전은 **공모 + 배당 중심**으로 온체인을 사용하고,  
2차 거래 온체인 연동은 이후 확장 포인트로 남겨두는 구조다.

---

## 5. 설계 원칙

1. 온체인은 최소하지만 “결정적인” 데이터만
   - 소유권/발행량/배당 수행 같은 정말 중요한 것만 최종 원장으로 유지.
2. 오프체인은 UX/규제/회계/리포트에 최적화
   - 각종 보고서와 화면, 회계처리를 빠르게 만들기 위해  
     오프체인 테이블들을 적극 활용.
3. 양쪽의 동기화는 blockchain_transactions 를 기준으로
   - 온체인 트랜잭션이 발생하면 항상 DB에 한 줄이 남고,
   - 장애 시 “이 트랜잭션이 실제로 블록에 있나?”를 역으로 검증 가능.
4. 리플레이/재계산 가능성 확보
   - holdings/배당 등은 온체인 이벤트 + DB 로그를 재생하면  
     동일 결과를 다시 계산할 수 있도록 설계하는 것을 목표로 한다.
