<!-- docs/04-backend-integration.md -->

# 04. 백엔드 연동 – Spring Boot + Besu

이 문서는 Spring Boot 백엔드가 **Hyperledger Besu 네트워크와 어떻게 통신하고,  
DB(RDS)와 함께 온체인 트랜잭션을 관리하는지**를 설명한다.

---

## 1. 전체 구조

    [프론트]
       ↓ HTTP/JSON
    [Spring Boot 백엔드]
       ├─ RDS(PostgreSQL)
       └─ Besu RPC (http://172.16.4.60:8545, VIP)
            ↓
          [스마트 컨트랙트]

- 프론트는 온체인/오프체인을 몰라도 되고,  
  오직 **백엔드 API만 호출**한다.
- 백엔드는
  - 도메인/비즈니스 로직 → DB
  - 자산/배당/토큰 발행 → 블록체인
  을 적절히 섞어서 처리한다.

---

## 2. 설정 – RPC URL, chainId, 가스 정책

### 2.1 application.yml 예시

    blockchain:
      enabled: true
      rpc-url: http://172.16.4.60:8545   # Besu RPC VIP
      chain-id: 1337                     # 예시 chainId
      from-address: 0x...                # 관리자(issuer) 지갑 주소
      private-key: ${BLOCKCHAIN_PRIVATE_KEY}  # Vault나 환경변수로 관리
      gas-price: 0                       # Besu --min-gas-price=0 에 맞춤
      gas-limit: 5_000_000

- gasPrice는 프라이빗 체인 특성상 0으로 고정.
- chainId는 genesis.json 에 정의된 값과 동일해야 한다.

---

## 3. BesuClient – 트랜잭션 전송 & 조회

백엔드 코드 (개념):  
com.masterpiece.IPiece.integration.besu.BesuClient

### 3.1 주요 역할

- Web3j 클라이언트를 통해
  - 컨트랙트 함수 호출(eth_call)
  - 트랜잭션 생성/서명/전송
  - receipt 조회
  를 수행.
- 예외 상황을 BlockchainException 등으로 래핑해서  
  서비스 레이어에서 처리하기 쉽도록 한다.

### 3.2 트랜잭션 전송 흐름(개념)

1. Function 인코딩
   - org.web3j.abi.FunctionEncoder 를 사용해  
     Solidity 함수 호출 데이터를 ABI 인코딩.
2. RawTransaction 생성
   - nonce 조회 (eth_getTransactionCount)
   - gasLimit, gasPrice(=0), chainId 설정
3. 서명 & 전송
   - TransactionEncoder.signMessage 로 서명
   - eth_sendRawTransaction 호출
4. 결과 처리
   - tx hash를 blockchain_transactions 에 임시로 기록
   - 별도의 폴링/비동기 로직으로 receipt를 조회하거나,  
     동기적으로 eth_getTransactionReceipt 를 기다려서 결과를 판단

---

## 4. DB 스키마와 매핑

### 4.1 blockchain_tokens

- 역할: 온체인에 배포된 토큰 정보와  
  오프체인 상품(product)을 연결하는 테이블.
- 주요 컬럼(개념)
  - token_id – PK
  - product_id – 어떤 상품과 매핑되는지
  - contract_address – ERC20/토큰 컨트랙트 주소
  - symbol, name
  - decimals
  - total_supply
  - deployed_at, deployment_tx_hash

### 4.2 blockchain_transactions

- 역할: 모든 온체인 트랜잭션을 DB에서 추적/감사할 수 있게 하는 테이블.
- 주요 컬럼(개념)
  - tx_id – PK
  - tx_hash
  - from_address, to_address
  - contract_address
  - method (예: transfer, mint, distributeDividend 등)
  - status (PENDING / SUCCESS / FAILED)
  - block_number, block_timestamp
  - request_payload (선택) – 호출 파라미터 JSON
  - response_payload (선택) – receipt, 에러메시지 등

### 4.3 holdings

- 역할: “사용자 기준” 보유 수량을 관리하는 테이블.
- 주요 컬럼(개념)
  - user_id
  - product_id
  - quantity
  - average_price 등
- 온체인의 balanceOf(address) 와 직접 1:1로 연결되기보다는,
  **입금/출금/체결/배당 기록을 통해 계산된 결과 값**으로 이해하면 된다.

---

## 5. 비즈니스 플로우별 연동

### 5.1 공모 상품 등록 → TokenFactory 호출

1. 관리자/운영자가 공모 상품 등록 API 호출
2. 백엔드
   - 상품/공모 정보(product, product_offering_info)를 DB에 저장
   - TokenFactory 컨트랙트 주소를 가져온 뒤
     - createTokenAndDistributor(...) 같은 함수를 호출
3. 온체인
   - SecurityTokenV2 + DividendDistributor 생성
   - 이벤트로 새 컨트랙트 주소를 방출
4. 백엔드
   - 이벤트/결과 값을 파싱해
     - blockchain_tokens 테이블에 레코드 추가
   - 동시에 blockchain_transactions 에 배포 트랜잭션 기록

### 5.2 공모 참여(청약) → 토큰 transfer

1. 사용자가 프론트에서 공모 참여 요청
2. 백엔드
   - 사용자의 예치금/잔고 검증 (balance_krw 혹은 KRWT 잔고)
   - 청약 가능 수량, 최소/최대 한도 검증
   - holdings, 청약 테이블 갱신
3. 온체인
   - 관리자 지갑에서 사용자 지갑으로  
     해당 종목의 SecurityTokenV2 를 transfer
4. 백엔드
   - 트랜잭션 해시를 blockchain_transactions 에 기록
   - 체결/청약 결과와 함께 응답 반환

> 장애 상황(예: 온체인 transfer 실패)에는  
> holdings/청약 테이블을 롤백하거나,  
> “DB는 SUCCESS인데 온체인 FAIL” 케이스를 트러블슈팅 리스트로 남겨  
> 운영자가 수동 조정하도록 설계할 수 있다.

### 5.3 배당

1. 운영자가 배당 선언 API를 통해 recordDate/payoutDate, totalAmount 설정.
2. recordDate 기준으로 holdings 를 스냅샷하여  
   각 user_id 가 받을 KRWT 금액 계산.
3. 온체인
   - KRWTV2를 사용해
     - 관리자 지갑 → 사용자 지갑으로 transfer 하거나
     - DividendDistributor를 통해 배당 수행
4. 백엔드
   - 각 트랜잭션 해시를 blockchain_transactions 에 기록
   - dividend_payouts 테이블에 user별 배당 이력 저장
   - 필요시 배당 총합과 온체인 KRWT 전송 총합이 일치하는지 검증

### 5.4 2차 거래

- 주문/체결은 오프체인에서 처리:
  - order_book, trades 등 테이블로 호가/체결 관리
- 온체인 연동은 두 모드 중 선택:
  1. 입·출금형
     - 사용자가 토큰을 “원장(블록체인)”에 예치/출금할 때만 온체인 호출
     - 내부 매수/매도는 holdings 로만 처리
  2. 체결연계형 (차후 확장)
     - 체결이 실제 지갑 간 토큰 이동까지 동반되도록  
       각 체결마다 transfer 호출

현재 IPiece는 **1차 발행/배당 중심** 온체인 구조를 우선으로 하고,  
2차 거래 온체인 연동은 점진적으로 확장 가능하도록 설계한다.

---

## 6. 트랜잭션 라이프사이클 & 에러 처리

### 6.1 기본 라이프사이클

1. 서비스/도메인 로직에서 BesuClient 를 호출해 트랜잭션 생성
2. eth_sendRawTransaction 응답으로 tx hash 획득
3. blockchain_transactions 테이블에
   - 상태: PENDING
   - 해시, 메서드, 파라미터 등을 기록
4. 별도의 폴링 또는 요청 흐름 내에서
   - eth_getTransactionReceipt 호출
   - 성공 시 status = SUCCESS, 블록번호/타임스탬프 기록
   - 실패 시 status = FAILED, 에러 로그 저장

### 6.2 자주 발생 가능한 이슈

#### (1) 트랜잭션이 PENDING에서 움직이지 않음

- 가능한 원인
  - 체인 레벨 문제
    - Validator 미기동, peer 0개
    - min-gas-price와 gasPrice 불일치
  - nonce 중복/꼬임
- 대응
  - 02. 인프라 문서의 점검 스크립트로 체인 상태 확인
  - 필요 시 nonce를 수동 조정하거나, 버려진 nonce를 채우는 트랜잭션 전송

#### (2) 이벤트 파싱 실패

- 증상
  - 컨트랙트는 정상 동작했는데,  
    백엔드에서 이벤트 로그를 파싱하다가 에러 발생
- 원인
  - Event 시그니처/파라미터 타입이  
    백엔드 TypeReference 정의와 불일치
  - ABI 업데이트를 반영하지 않고,  
    이전 버전 코드로 디코딩 시도
- 대응
  - 컨트랙트 ABI와 백엔드의 이벤트 타입 정의를 일치
  - 테스트 환경에서 미리 이벤트 파싱 단위를 검증

#### (3) DB와 온체인 상태 불일치

- 케이스 예시
  - 온체인 transfer는 성공했는데,  
    blockchain_transactions 가 FAILED 로 기록됨
  - holdings 잔고가 balanceOf 와 다른 값
- 대응 전략
  1. 주기적인 리컨실리이션(reconciliation) 배치
     - 특정 시점에 balanceOf 와 holdings 를 비교
  2. blockchain_transactions 기준으로  
     “실제로 블록에 포함된 것만 SUCCESS로 간주”하도록 보정
  3. 운영자용 관리 화면/툴에서  
     특정 트랜잭션을 다시 조회/재반영할 수 있게 설계

---

## 7. 요약

- 블록체인은 백엔드와만 연결되어 있고,
- 백엔드는
  - DB로 비즈니스/규제/UX에 최적화된 데이터를 관리하고
  - Besu RPC를 통해 **핵심 자산 상태(토큰/배당)를 온체인에 기록**한다.
- blockchain_tokens, blockchain_transactions, holdings 를 축으로  
  온체인과 오프체인의 상태를 연결/동기화하는 것이  
  IPiece 온체인 연동 설계의 핵심이다.
