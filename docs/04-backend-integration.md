# 04. 백엔드 – Besu 연동 (Spring Boot × 프라이빗 체인)

IPiece 백엔드에서 **Spring Boot + Web3j + BesuClient** 조합으로 Hyperledger Besu 프라이빗 체인과 통신하는 구조 정리입니다.  
실제 코드 기준 레포지토리입니다.

- 백엔드: `IPiece` (Spring Boot, Web3j, PostgreSQL)
- 온체인: `IPiece-blockchain` (Besu, Solidity, Foundry)
- 주요 패키지
  - `com.masterpiece.IPiece.blockchain.config.Web3jConfig`
  - `com.masterpiece.IPiece.integration.besu.BesuClient`
  - `com.masterpiece.IPiece.blockchain.application.*`
  - `com.masterpiece.IPiece.investment.application.InvestmentService`
  - `com.masterpiece.IPiece.admin.blockchain.application.*`


---

## 1. Spring Boot 백엔드와 Besu의 통신방식

### 1.1 전체 구성 개요

- **네트워크 진입점**
  - Besu RPC 노드 2대 + keepalived
  - VIP: `http://172.16.4.60:8545` (예시)
  - Spring Boot는 VIP만 바라보는 구조입니다.

- **구성 요소**
  - `Web3jConfig`
    - RPC URL 기반으로 `Web3j` 생성
    - `admin.private-key` 로 `Credentials` 생성
  - `BesuClient`
    - Web3j + Credentials + 컨트랙트 주소 + chainId를 묶어서 제공
    - raw 트랜잭션 생성, 서명, 브로드캐스트, receipt 조회 담당
  - 도메인 서비스
    - `WalletService` : KRWT 발행/소각, 지갑 조회
    - `BlockchainService` : 토큰 생성, 토큰 전송, 화이트리스트, 잔액 조회
    - `BlockchainDividendService` : 배당 실행/시뮬레이션
    - `BlockchainReceiptScheduler` : `blockchain_transactions` PENDING → SUCCESS/FAILED 업데이트
    - `InvestmentService` : 공모 투자 시 온체인 흐름 연결
    - `AdminBlockchainStatusService` : 체인 상태 조회
    - `AdminBlockchainTransactionService` : 온체인 트랜잭션 이력 조회

- **읽기 vs 쓰기**
  - 읽기용
    - `eth_blockNumber`, `eth_getBalance`, `balanceOf`, `whitelist`, `owner` 등
    - 대부분 `BlockchainService`, `WalletService`, `AdminBlockchainStatusService` 에서 사용
  - 쓰기용
    - `mint`, `burn`, `transfer`, `forceTransfer`, `createToken`, `distribute` 등
    - 전부 `BesuClient` 가 raw 트랜잭션 생성 후 `eth_sendRawTransaction` 으로 전송합니다.


### 1.2 Web3jConfig – 기본 연결

`com.masterpiece.IPiece.blockchain.config.Web3jConfig`

- 설정 값
  - `besu.rpc-url`  
    → 예: `http://172.16.4.60:8545`
  - `admin.private-key`  
    → 관리자 EOA 개인 키 (64자리 hex, `0x` 제외)
  - `blockchain.enabled`  
    → `true` 일 때만 Web3j/Blockchain 관련 Bean 생성

- 동작 흐름
  1. 애플리케이션 시작 시 `web3j()` Bean 생성
     - `new HttpService(besuRpcUrl)` 로 RPC 연결
     - `web3j.web3ClientVersion().send()` 호출로 기동 확인
  2. `adminCredentials()` Bean 생성
     - `Credentials.create(adminPrivateKey)`
     - `admin` 계정 주소 로그 출력
  3. 이후 모든 온체인 write 트랜잭션은 이 Credentials로 서명


### 1.3 BesuClient – 온체인 통신 래퍼

`com.masterpiece.IPiece.integration.besu.BesuClient`

- 주입 값
  - `Web3j web3j`
  - `admin.private-key`
  - `krwt.contract.address`
  - `tokenfactory.contract.address`
  - `besu.chain-id` (hex 문자열, 예: `0x1350195`)
  - `besu.tx.gas-limit.default` (기본 3,000,000 으로 하드코딩된 디폴트 사용)

- 내부 필드
  - `BigInteger gasPrice = BigInteger.ONE`  
    → 항상 **1 wei** 로 고정  
      (Besu 노드의 `--min-gas-price=0` 설정과 맞춰 사용)
  - `BigInteger defaultGasLimit`  
    → estimateGas 실패 시 fallback 값
  - `String krwtContractAddress`  
    → KRWTV2(현금 토큰) 주소
  - `String tokenFactoryAddress`  
    → TokenFactory 주소
  - `BigInteger chainId`  
    → EIP-155 서명에 사용
  - `String adminAddress`  
    → `credentials.getAddress()` 에서 계산된 관리자 주소

- 주요 책임
  - **주소/해시 형식 검증**
    - `0x` + 40자 hex (address)
    - `0x` + 64자 hex (txHash)
  - **읽기 함수**
    - `getKrwtBalance(address)`
    - `getTokenBalance(tokenAddress, holderAddress)`
    - `isWhitelisted(tokenAddress, walletAddress)`
    - `getChainId()`, `getNetworkId()`, `getLatestBlockSummary()` 등
  - **쓰기 함수**
    - KRWT
      - `mintKrwt(to, amount)`
      - `burnKrwt(from, amount)`
      - `transferKrwt(to, amount)`  
        (관리자 → 사용자, 배당 등)
      - `transferKrwtFrom(from, to, amount)`  
        (관리자 강제 송금, 공모 징수/체결 정산)
    - 보안토큰(SecurityTokenV2)
      - `transferToken(token, to, amount)`  
        (관리자 → 사용자, 공모 배분/2차거래 특수 상황 등)
      - `transferTokenFrom(token, from, to, amount)`  
        (2차 거래 체결 시 seller → buyer)
      - `addToWhitelist(token, wallet)`
      - `isWhitelisted(token, wallet)` (view 함수 호출)
    - TokenFactory
      - `createTokenViaFactory(name, symbol, totalSupply)`  
        → `TokenCreated` 이벤트에서 `(name, symbol, tokenAddress, dividendAddress, totalSupply)` 파싱
    - 배당(배포된 DividendDistributor)
      - `distribute` 호출은 `BlockchainDividendService` 에서 직접 web3j Generated Wrapper 사용
  - **트랜잭션 전송 공통 로직**
    1. `eth_estimateGas` 로 예상 gas 사용량 조회
    2. 실패 시 `defaultGasLimit` 사용
    3. `RawTransaction.createTransaction(...)` 로 legacy tx 생성
    4. `TransactionEncoder.signMessage(rawTx, chainId, credentials)`
    5. `eth_sendRawTransaction` 호출
    6. 필요 시 `waitForTransactionReceipt(txHash)` 로 블록에 포함될 때까지 polling


### 1.4 호출 계층 구조

- Controller 계층
  - 예: `WalletController`, `BlockchainController`, 투자/공모/배당 관련 컨트롤러
  - JWT에서 `@CurrentUser Long userId` 를 받아 서비스 호출

- Application 서비스 계층
  - 예: `WalletService`, `BlockchainService`, `InvestmentService`, `BlockchainDividendService`
  - **도메인 로직 + DB 작업 + BesuClient 호출을 하나의 트랜잭션 단위로 묶는 계층**입니다.

- Integration 계층
  - `BesuClient`
  - Web3j, ABI 인코딩/디코딩, 트랜잭션 서명/전송, receipt 조회 담당

정리:

> 프론트 요청 → Spring Controller → 도메인 서비스  
> → (DB 검증/상태 변경) → BesuClient로 온체인 함수 호출  
> → txHash 및 결과를 DB(`blockchain_transactions`, `krwt_operations` 등)에 저장


---

## 2. RPC URL, chainId, gasPrice, legacy 트랜잭션 정책

### 2.1 RPC URL

- 설정 키
  - `besu.rpc-url: ${BESU_RPC_URL}`
- 예시 값
  - `http://172.16.4.60:8545` (RPC VIP)
- 특징
  - RPC 노드 2대 + keepalived로 VIP 이중화
  - 백엔드는 VIP만 바라보므로, RPC 노드 장애 시에도 애플리케이션 설정 변경 불필요


### 2.2 chainId

- Besu 제네시스 설정
  - `chainId: 20251029`
- 애플리케이션 설정
  - `besu.chain-id: ${BLOCKCHAIN_CHAIN_ID}`
  - 디폴트: `"0x1350195"` (16진수 문자열)
- 사용 목적
  - `TransactionEncoder.signMessage(rawTx, chainId, credentials)` 에 사용
  - 다른 체인과의 리플레이 공격 방지를 위해 체인별 고유한 chainId 사용


### 2.3 gasPrice 정책

- Besu 노드
  - 기동 시 `--min-gas-price=0` 옵션 사용
  - 프라이빗 체인, 검증자/사용자 모두 내부이므로 가스비 실질적 0원

- 백엔드(BesuClient)
  - `gasPrice = BigInteger.ONE`
  - 이유
    - 일부 Besu 설정/도구와의 호환성, “0이 아닌 값”을 요구하는 환경 고려
    - 실제 비용 관점에서는 1 wei ≒ 0원 취급

- 주의점
  - 프라이빗 체인이므로 `gasPrice` 가 비용 이슈로 이어지지 않음
  - 퍼블릭 체인으로 옮기는 상황에서는 반드시 정책 재검토 필요


### 2.4 gasLimit 정책

- 애플리케이션 설정
  - `besu.tx.gas-limit: 1000000` (현재는 직접 사용하지 않고 디폴트 3,000,000 적용)
- BesuClient 내부
  - `besu.tx.gas-limit.default:3000000` (어노테이션 디폴트)
  - 실제 estimate 실패 시 이 값을 사용

- 동작 순서
  1. 우선 `eth_estimateGas` 호출
  2. 정상 응답이면 그 값 사용
  3. 오류 또는 0 반환 시 `defaultGasLimit` 사용
  4. 가끔 비정상 트랜잭션(예: revert 예상)에서도 estimateGas 가 낮은 값을 줄 수 있으므로, 기본 값 자체를 넉넉하게 설정


### 2.5 Legacy 트랜잭션 정책

- 사용 타입
  - **Legacy 타입** 트랜잭션 일관 사용
  - EIP-1559 (`maxFeePerGas`, `maxPriorityFeePerGas`) 사용하지 않음
- 이유
  - Hyperledger Besu 프라이빗 체인
  - `gasPrice` 고정, baseFee 개념 불필요
  - EIP-1559 설정 복잡성을 줄이고 운영 단순화


---

## 3. 공모/배당 등 비즈니스 플로우와 온체인 트랜잭션 연결 구조

### 3.1 큰 그림

비즈니스 흐름을 아주 단순하게 말로 그리면 다음과 같은 구조입니다.

> 1. **사용자 또는 관리자**가 API 호출  
> 2. **백엔드 서비스**가 DB에서 현재 상태를 확인  
> 3. 문제가 없으면 **BesuClient로 스마트컨트랙트 함수 호출**  
> 4. **txHash** 를 받아서 DB에 기록  
> 5. 필요 시 **스케줄러**가 receipt를 보고 SUCCESS/FAILED로 상태 변경  
> 6. 프론트는 DB를 조회하여 “진행 중 / 성공 / 실패”를 확인

이제 각 비즈니스별로, **“누가 버튼을 누르면, 어떤 DB가 먼저 바뀌고, 어떤 컨트랙트 함수가 호출되고, 그 결과를 어디에 쓰는지”** 를 하나씩 봅니다.


---

### 3.2 KRWT 발행/소각 (WalletService)

#### 3.2.1 KRWT 발행 (관리자 → 사용자)

- 관련 API
  - `POST /v1/wallet/krwt/mint`
- 관련 클래스
  - `WalletController.mintKrwt`
  - `WalletService.mintKrwt`
  - `BesuClient.mintKrwt`
  - `KrwtOperation`, `VirtualAccount`, `VirtualAccountJournal`

- 한 줄 요약  
  → **관리자가 “입금” 버튼을 누르면, 사용자의 가상계좌 잔액과 온체인 KRWT 잔액이 함께 늘어나는 흐름입니다.**

- 상세 순서

1. **입력값**
   - 관리자가 UI에서
     - 대상 사용자 ID (`userId`)
     - 발행 금액 (`amount`, 예: 100000)
     - 메모 (`memo`)
     를 입력합니다.

2. **컨트롤러 단계**
   - `WalletController.mintKrwt(adminUserId, request)`
   - 현재 로그인한 관리자 계정의 `adminUserId` 는 JWT에서 가져옵니다.
   - `request` 는 `KrwtMintRequest { userId, amount, memo }` 입니다.
   - `WalletService.mintKrwt(adminUserId, request)` 호출

3. **서비스 – 사전 검증**
   - 금액 검증
     - 0보다 크고, `MAX_MINT_AMOUNT` (예: 10억) 이하인지 확인
   - 대상 사용자 가상계좌 조회
     - `VirtualAccountRepository` 로 `request.userId` 의 계좌 찾기
     - 없으면 `BusinessException(INVALID_USER)` 발생

4. **KRWT 발행 작업을 기록할 row 생성**
   - `KrwtOperation` 엔티티 생성
     - `operationType = MINT`
     - `amount = 발행 금액`
     - `beforeBalance = 현재 가상계좌 잔액`
     - `status = PENDING`
     - `memo`, `bankTransactionId` 등 필요한 필드 채움
   - `krwtOperationRepository.save(pendingOp)`

5. **온체인 트랜잭션 전송**
   - `besuClient.mintKrwt(사용자_지갑주소, amount)` 호출
   - 내부에서는
     - `Function("mint", [to, amount])` 생성
     - `estimateGas` → `RawTransaction` → `eth_sendRawTransaction`
   - txHash 문자열 반환

6. **DB 반영 – 성공 케이스**
   - 가상계좌 잔액 증가
     - `virtualAccount.increaseBalanceKrw(amount)`  
       (예: 1,000,000원 → 1,100,000원)
   - `pendingOp.updateStatus(SUCCESS, txHash, completedAt)`
   - `VirtualAccountJournal` 생성
     - `txType = "DEPOSIT"`
     - `amountKrw = amount`
     - `balanceAfter = 증가된 잔액`
     - `description = "KRWT 입금"`
   - 관련 엔티티 저장

7. **DB 반영 – 실패 케이스**
   - 온체인 트랜잭션 단계에서 예외 발생 시
     - `pendingOp.updateStatus(FAILED, null, completedAt)` 로 바뀜
     - `KrwtOperation` 저장
   - 가상계좌 잔액은 변경되지 않습니다.
   - `BusinessException(BLOCKCHAIN_TRANSACTION_FAILED)` 발생 → API 에러 응답으로 전달

8. **결과 응답**
   - `KrwtMintResponse`
     - `transactionId` (KrwtOperation PK)
     - `userId`
     - `previousBalance`
     - `mintAmount`
     - `newBalance`
     - `transactionHash`
     - `completedAt`


#### 3.2.2 KRWT 소각 (사용자 → 시스템)

- 관련 API
  - `POST /v1/wallet/krwt/burn`
- 관련 클래스
  - `WalletService.burnKrwt`
  - `BesuClient.burnKrwt`
  - `KrwtOperation`, `VirtualAccount`, `VirtualAccountJournal`

- 한 줄 요약  
  → **사용자가 “출금/환불” 버튼을 눌렀을 때, 가상계좌 잔액과 온체인 KRWT 잔액이 함께 줄어드는 흐름입니다.**

- 상세 순서

1. **입력값**
   - 관리자/운영자가
     - 소각 대상 사용자 ID (`userId`)
     - 소각 금액 (`amount`)
     - 메모 (`memo`)
     를 입력합니다.

2. **사전 검증**
   - 금액 > 0 확인
   - 대상 사용자 가상계좌 조회
   - 현재 잔액이 소각 금액 이상인지 확인
     - 부족하면 `INSUFFICIENT_BALANCE` 에러

3. **KrwtOperation 생성**
   - `operationType = BURN`
   - `beforeBalance = 현재 잔액`
   - `amount = 소각 금액`
   - `status = PENDING`

4. **온체인 트랜잭션**
   - `besuClient.burnKrwt(userWalletAddress, amount)`
   - txHash 반환

5. **DB 반영 – 성공**
   - `virtualAccount.decreaseBalanceKrw(amount)`
   - `pendingOp.updateStatus(SUCCESS, txHash, completedAt)`
   - `VirtualAccountJournal` 에
     - `txType = "WITHDRAW"`
     - `amountKrw = -amount`
     - `balanceAfter = 감소된 잔액`
     기록 후 저장

6. **DB 반영 – 실패**
   - `pendingOp.updateStatus(FAILED, null, completedAt)`
   - 잔액 변화 없음
   - 에러 로그 + `BLOCKCHAIN_TRANSACTION_FAILED` 예외


---

### 3.3 프로젝트 토큰 생성 (TokenFactory)

#### 3.3.1 프로젝트/토큰 생성 API

- 관련 API
  - `POST /v1/blockchain/tokens`
- 관련 클래스
  - `BlockchainController.createToken`
  - `BlockchainService.createToken`
  - `BesuClient.createTokenViaFactory`
  - `BlockchainToken` 엔티티

- 한 줄 요약  
  → **관리자가 프로젝트를 등록하면서, 온체인에 SecurityTokenV2(종목 토큰) + DividendDistributor(배당 컨트랙트)를 한 번에 배포하는 흐름입니다.**

- 상세 순서

1. **입력값**
   - `CreateTokenRequest`
     - `name` : 토큰 이름 (예: "MANGU 시즌1 토큰")
     - `symbol` : 토큰 심볼 (예: "MANGU1")
     - `totalSupply` : 초기발행수량
     - `faceValue` : 액면가

2. **컨트롤러 → 서비스**
   - `BlockchainService.createToken(request, adminUserId)` 호출

3. **사전 검증**
   - `totalSupply > 0` 확인
   - TokenFactory 주소 존재 여부 확인
     - `tokenFactoryAddress` 비어 있으면 `BLOCKCHAIN_ERROR` 로 즉시 실패

4. **온체인 호출**
   - `besuClient.createTokenViaFactory(name, symbol, totalSupply)`
   - 내부 처리
     - `Function("createToken", [name, symbol, totalSupply, adminAddress])` (컨트랙트 설계에 따라 owner 포함)
     - `eth_sendRawTransaction` 호출
     - `waitForTransactionReceipt(txHash)`
     - receipt의 로그에서 `TokenCreated` 이벤트 파싱
       - `tokenAddress` (SecurityTokenV2 주소)
       - `dividendAddress` (DividendDistributor 주소)
       - `totalSupply` (확인용)

5. **DB 반영**
   - `BlockchainToken` 엔티티 생성
     - `name`, `symbol`, `totalSupply`, `faceValue`
     - `ownerUserId = adminUserId`
     - `contractAddress = tokenAddress`
     - `transactionHash = txHash`
     - `status = DEPLOYED`
   - 주소 비어 있으면 `BLOCKCHAIN_ERROR("생성된 토큰 주소를 확인할 수 없습니다")` 로 예외

6. **응답**
   - `CreateTokenResponse`
     - `contractAddress`
     - `transactionHash`
     - `name`, `symbol`, `totalSupply`, `faceValue`, `createdAt`


---

### 3.4 공모 참여(투자)

#### 3.4.1 공모 투자 요청

- 관련 API
  - 공모 투자: `POST /v1/investments`
- 관련 클래스
  - `InvestmentService.invest(InvestmentRequest request, Long userId, Long adminUserId)`
  - `BlockchainService.addToWhitelist`
  - `BlockchainService.transferToken`
  - `BlockchainTransaction` 엔티티

- 한 줄 요약  
  → **사용자가 공모에 참여하면, DB에 투자 내역을 먼저 저장**

- 상세 순서 (단순화 버전)

1. 사용자가 공모 화면에서
   - `projectId`
   - `tokenAmount`
   - `amount` (KRWT 금액)
   입력 후 “투자하기” 버튼 클릭

2. 백엔드에서 투자 전 검증
   - `ProductRepository` 로 프로젝트 존재 여부 확인
   - 해당 프로젝트의 `tokenContractAddress` 존재 여부 확인
   - 사용자의 지갑 주소 존재 여부 확인
   - 투자 가능 상태, 최소/최대 수량, 마감시간 등 비즈니스 룰 체크

3. `Investment` 엔티티 생성
   - 상태: `PENDING` 또는 `REQUESTED`
   - `amount`, `tokenAmount`, `user`, `product` 등 저장

4. 사용자 KRWT 이동
   - 공모 참여한 액수만큼 KRWT가 사용자 -> 관리자로 이동
---

### 3.5 공모 → 2차거래 전환 (enableSecondaryTrading)

이 부분은 관리자가 특정 상품을 2차 거래로 전환할 때의 흐름입니다. (사용자가 “이제 이 상품은 장터에서 거래 가능” 상태로 넘어가는 시점)

- 관련 서비스
  - `AdminProductService.enableSecondaryTrading(...)`
  - `InvestmentService`, `BlockchainService`
  - Besu 단에서는 결국 **여러 번의 `addToWhitelist + transferToken` 반복 호출**입니다.

- 한 줄 요약  
  → **공모 기간 동안 누적된 투자 내역을 합쳐서, 각 사람에게 온체인 토큰을 실제로 배분해주고, 상품 상태를 TRADE로 바꾸는 흐름입니다.**

- 예시 단계 (개념 기준)

1. 관리자 백오피스에서
   - `POST /v1/admin/products/{productId}/enable-offering` (예시)
   - 바디: `{ "confirm": true }`
   - 인증: admin JWT 필요

2. 서비스 계층 – 집계
   - 해당 `productId` 의 공모 투자 내역 조회
   - 투자자별로 `총 토큰 수량`, `총 투자금` 계산
   - “1번 유저 100개, 2번 유저 50개, …” 형태의 목록 생성

3. 온체인 처리 (반복 루프)
   - 각 투자자에 대해
     1) 화이트리스트 추가  
        → `besuClient.addToWhitelist(tokenContractAddress, userWallet)`
     2) 토큰 전송  
        → `besuClient.transferToken(tokenContractAddress, userWallet, tokenQuantity)`

   - 토큰 전송 때마다
     - `BlockchainTransaction` 에 `PENDING` 레코드 추가
     - 후속 스케줄러로 SUCCESS/FAILED 업데이트

4. 오프체인 상태 정리
   - `holdings` 테이블에 투자자별 보유 수량 기록
   - 공모 관련 테이블 상태를 “완료”로 변경
   - 상품 상태를 `OFFERING` → `TRADE` 로 변경

5. 사용자 관점
   - 마이페이지/보유자산에서 해당 상품이 “2차거래 가능”으로 보이기 시작
   - 차트/호가창 메뉴 활성화


---

### 3.6 2차 거래 체결 정산 (OrderBook × Besu)

#### 3.6.1 settleTradeOnChain

- 관련 메서드
  - `BlockchainService.settleTradeOnChain(OrderBook buyOrder, OrderBook sellOrder, long qty, long price)`
  - `BesuClient.transferTokenFrom`
  - `BesuClient.transferKrwtFrom`
  - `BlockchainTransaction`

- 한 줄 요약  
  → **주문/호가/체결은 전부 DB에서 처리하고, 최종 체결된 결과만 온체인에 “토큰 이동 + KRWT 이동” 두 번의 트랜잭션으로 반영하는 흐름입니다.**

- 상세 순서

1. **입력값**
   - `buyOrder`, `sellOrder` : 체결된 주문
   - `qty` : 체결 수량
   - `price` : 체결 단가
   - 두 주문 모두 동일한 `product` 를 가리킴

2. **준비 작업**
   - `tokenContractAddress = buyOrder.getProduct().getTokenContractAddress()`
   - null/빈 문자열이면 로그만 남기고 리턴 (안전장치)
   - `buyerWalletAddress`, `sellerWalletAddress` 추출
   - `totalKrwtAmount = qty * price`

3. **1단계 – 종목 토큰 이동 (seller → buyer)**
   - `besuClient.transferTokenFrom(tokenContractAddress, sellerWallet, buyerWallet, qty)`
   - txHash 반환
   - `BlockchainTransaction` 생성
     - `fromAddress = sellerWalletAddress`
     - `toAddress = buyerWalletAddress`
     - `tokenAddress = tokenContractAddress`
     - `amount = qty`
     - `transactionType = TRANSFER`
     - `transactionStatus = PENDING`
     - `user = seller`
   - 저장

4. **2단계 – KRWT 이동 (buyer → seller)**
   - `besuClient.transferKrwtFrom(buyerWallet, sellerWallet, totalKrwtAmount)`
   - txHash 반환
   - `BlockchainTransaction` 생성
     - `fromAddress = buyerWalletAddress`
     - `toAddress = sellerWalletAddress`
     - `tokenAddress = krwtContractAddress`
     - `amount = totalKrwtAmount`
     - `transactionType = TRANSFER`
     - `transactionStatus = PENDING`
     - `user = buyer`
   - 저장

5. **예외 처리**
   - 두 단계 중 하나라도 예외 발생 시
     - `BlockchainException("On-chain settlement failed")` 발생
     - 해당 서비스 메서드는 트랜잭션 롤백
     - DB 기준 체결 상태도 함께 롤백되어 **오프체인/온체인 불일치 최소화**


---

### 3.7 공모 KRWT 징수 (비동기 정산)

- 관련 메서드
  - `BlockchainService.transferKrwtForOffering(Long userId, String walletAddress, long totalPrice)`

- 한 줄 요약  
  → **공모 참여 후, 사용자의 KRWT를 관리자 지갑으로 “한 번에” 옮겨오는 흐름입니다. DB 트랜잭션과 분리된 비동기 작업입니다.**

- 상세 순서

1. 입력값
   - `userId`, `walletAddress`, `totalPrice` (사용자가 공모에 투자한 총 KRWT)

2. 온체인 호출
   - `from = walletAddress`, `to = adminAddress`
   - `besuClient.transferKrwtFrom(from, to, totalPrice)`
   - txHash 반환

3. receipt 대기
   - `besuClient.waitForReceipt(txHash)` 로 직접 receipt 조회
   - receipt 없거나 status != OK 이면 경고 로그 후 리턴 (실패로 판단하지만 예외는 외부로 던지지 않음)

4. DB 기록
   - `BlockchainTransaction` 생성
     - `txHash`
     - `fromAddress = from`
     - `toAddress = to`
     - `tokenAddress = krwtContractAddress`
     - `amount = totalPrice`
     - `transactionType = TRANSFER`
     - `transactionStatus = SUCCESS`
     - `blockNumber`, `blockHash`, `gasUsed`
     - `user = userRepository.findById(userId)`
   - 저장

5. 특징
   - 이미 공모 DB 트랜잭션은 완료된 이후에 실행되는 비동기 흐름
   - 실패해도 공모 데이터는 유지, 운영자가 별도 점검 필요


---

### 3.8 배당 실행 (BlockchainDividendService)

#### 3.8.1 배당 실행 API

- 관련 API
  - `POST /v1/admin/dividends/execute` (예시)
- 관련 클래스
  - `BlockchainDividendService.executeDividend`
  - `DividendDistributor` 컨트랙트 Wrapper (web3j)
  - `BlockchainTransaction` + `Dividends` 엔티티

- 한 줄 요약  
  → **관리자가 특정 상품에 대해 배당을 선언하고, KRWT 기반 배당금을 온체인에서 분배하는 흐름입니다.**

- 상세 순서

1. 입력값
   - `DividendExecuteRequest`
     - `projectId` (상품 ID)
     - `recordDate` (기준일)
     - `paymentDate` (지급일)
     - `totalAmount` (총 KRWT 배당금)

2. 준비 단계
   - 관리자 `User` 조회 (userId 기준)
   - `productRepository` 로 상품 조회
   - 상품에 배당 컨트랙트 주소가 등록되어 있는지 확인
     - 없으면 `CONTRACT_ADDRESS_NOT_FOUND`

3. 온체인 배당 실행
   - web3j로 `DividendDistributor` 컨트랙트 로딩
     - `DividendDistributor.load(dividendContractAddress, web3j, adminCredentials, gasPrice, gasLimit)`
   - `distribute(totalAmount).send()` 호출
   - `TransactionReceipt` 수신

4. `blockchain_transactions` 기록
   - `BlockchainTransaction` 생성
     - `txHash = receipt.transactionHash`
     - `fromAddress = receipt.from`
     - `toAddress = receipt.to`
     - `tokenAddress = dividendContractAddress` (배당 컨트랙트 주소)
     - `amount = totalAmount`
     - `transactionType = DIVIDEND`
     - `transactionStatus = SUCCESS/FAILED` (receipt status 기준)
     - `blockNumber`, `blockHash`, `gasUsed`
     - `user = adminUser`
   - 저장

5. `dividends` 테이블 기록
   - `Dividends` 엔티티 생성
     - `product`
     - `recordDate`, `payoutDate`
     - `totalAmount`
     - `transactionHash`
     - `blockNumber`
     - `status = COMPLETED/FAILED`
   - 저장

6. 응답
   - `DividendExecuteResponse`
     - `dividendId`, `projectId`, `projectName`
     - `totalAmount`, `recordDate`, `paymentDate`
     - `transactionHash`, `status`, `executedAt`


#### 3.8.2 배당 시뮬레이션 (Off-chain만 사용)

- `BlockchainDividendService.simulateDividend(DividendSimulateRequest)`
- 온체인 호출 없이 DB의 `Holdings` 기준으로
  - 토큰별 보유 수량
  - 예상 배당금
  - 상위 홀더 목록
  계산
- 실제 분배는 위의 `executeDividend` 에서 온체인 호출로 수행


---

## 4. 온체인 트랜잭션을 `blockchain_transactions` 에 관리하는 규칙

### 4.1 테이블 스키마 개요

`com.masterpiece.IPiece.blockchain.domain.BlockchainTransaction`

주요 컬럼 요약입니다.

| 컬럼명 | 설명 |
|-------|------|
| `tx_id` | PK |
| `tx_hash` | 온체인 트랜잭션 해시 (`0x` + 64 hex) |
| `from_address` | 보내는 주소 |
| `to_address` | 받는 주소 |
| `token_address` | 관련 토큰/컨트랙트 주소 (KRWT, SecurityTokenV2, DividendDistributor 등) |
| `amount` | 이동 금액 (BigDecimal, 토큰 수량 또는 KRWT 수량) |
| `transaction_type` | `TRANSFER`, `MINT`, `BURN`, `DIVIDEND`, `TRADE`, `OTHER` |
| `transaction_status` | `PENDING`, `SUCCESS`, `FAILED` |
| `block_number` | 포함된 블록 번호 (nullable) |
| `block_hash` | 블록 해시 (nullable) |
| `gas_used` | 사용된 가스량 (nullable) |
| `error_message` | 실패 사유 메시지 (nullable) |
| `user_id` | 관련 사용자 (FK) |
| `investment_id` | 관련 공모 투자 (FK, nullable) |
| `created_at`, `updated_at` | 생성/수정 시각 |

추가로, KRWT 발행/소각은 `blockchain_transactions` 가 아니라 `KrwtOperation` 테이블로 관리합니다.


### 4.2 기록 규칙 – 언제 PENDING / 언제 SUCCESS

#### 4.2.1 PENDING 으로 먼저 넣는 경우

다음 케이스는 **txHash만 알고, 실제 블록 포함 여부는 나중에 스케줄러가 확인**합니다.

- 공모 토큰 전송
  - `BlockchainService.transferToken` 내부
- 2차 거래 체결 정산
  - `BlockchainService.settleTradeOnChain`
  - 종목 토큰 이동 + KRWT 이동 모두 `PENDING`
- 그 외 BesuClient 직접 호출 후 즉시 receipt를 기다리지 않는 패턴

이 경우 흐름입니다.

1. 서비스 메서드에서 `BlockchainTransaction` 생성
   - `transactionStatus = PENDING`
   - `blockNumber`, `blockHash`, `gasUsed` 는 null
2. 스케줄러(`BlockchainReceiptScheduler`)가 poll
   - `findTop100ByTransactionStatusOrderByCreatedAtAsc(PENDING)` 로 최대 100건 조회
   - `besuClient.fetchTransactionReceipt(txHash)` 로 receipt 조회
3. receipt 없음
   - 아직 블록에 안 올라간 상태
   - 다음 라운드에서 다시 시도
4. receipt 존재
   - `receipt.status == "0x1"` 이면 `markSuccess`
   - 아니면 `markFailed("Receipt status != 0x1", …)`


#### 4.2.2 처음부터 SUCCESS/FAILED 로 넣는 경우

아래는 서비스 메서드 내부에서 **바로 `waitForReceipt` 를 호출**하고, 그 결과에 따라 곧바로 SUCCESS/FAILED 를 정하는 패턴입니다.

- 배당 실행 (`BlockchainDividendService.executeDividend`)
- 공모 KRWT 징수 (`BlockchainService.transferKrwtForOffering`)

이 경우 흐름입니다.

1. BesuClient 또는 web3j Wrapper 로 함수 호출 (`send()` 또는 `waitForReceipt`)
2. receipt 를 바로 얻은 뒤
   - `transactionStatus` 를 `SUCCESS` 또는 `FAILED` 로 설정해 `BlockchainTransaction` 생성
3. 스케줄러는 이 row를 건드리지 않음  
   (PENDING 이 아니기 때문)


### 4.3 TransactionType 사용 규칙

- `TRANSFER`
  - 토큰/현금 이동 대부분
  - 공모 토큰 배정, 2차 거래 정산, 공모 KRWT 징수, 기타 일반 이동
- `DIVIDEND`
  - 배당 실행 트랜잭션
- `MINT`, `BURN`
  - 필요 시 확장용 (현재는 KRWT 발행/소각을 `KrwtOperation` 으로 관리하고 있어 잘 쓰지 않음)
- `TRADE`
  - 추후 2차 거래에 특화된 타입이 필요할 때 사용 가능
  - 현재 구현에서는 DB 제약과 일관성을 위해 대부분 `TRANSFER` 로 기록


### 4.4 Admin 조회 화면과의 연결

- `AdminBlockchainTransactionService`
  - `AdminBlockchainTransactionQueryRepository` 를 통해
    - `userId`, `transactionType`, `transactionStatus`, `productId`, 기간 등으로 검색
  - 결과를 `AdminBlockchainTransactionListResponse` 로 변환
- 운영자는
  - 특정 사용자/상품의 온체인 트랜잭션 히스토리를 이 화면에서 조회
  - 문제 발생 시 txHash를 클릭하여 RPC에서 직접 receipt 확인 가능


---

## 5. 트러블슈팅

### 5.1 RPC / chainId / 연결 문제

#### 증상

- 애플리케이션 기동 시
  - `❌ Besu 연결 실패` 로그
- 온체인 연동 API 호출 시
  - `BlockchainException("Failed to fetch ...")`
  - HTTP 5xx 에러

#### 체크리스트

1. `application.yml` 의 `besu.rpc-url` 확인  
   → VIP 주소(`172.16.4.60:8545`)와 일치하는지
2. Besu RPC 노드 상태
   - `curl http://172.16.4.60:8545` 로 응답 확인
   - `eth_chainId`, `eth_blockNumber` 호출 테스트
3. chainId 불일치
   - 제네시스의 `chainId` 와 `besu.chain-id` 설정이 같아야 함  
   - 베타/로컬 환경 섞여 있을 경우 주의


### 5.2 관리자 Private Key / 컨트랙트 owner 불일치

#### 증상

- KRWT 발행/소각, TokenFactory, SecurityToken 관련 함수 호출 시
  - 항상 revert
  - “caller is not the owner” 류의 에러 메시지 (revert reason)

#### 원인

- 스마트컨트랙트의 `owner()` 주소와
- 백엔드에서 사용하는 `admin.private-key` 의 주소가 서로 다름

#### 해결

1. 배포된 컨트랙트의 owner 조회
   - `cast call $KRWT "owner()(address)" --rpc-url $RPC_URL`
   - SecurityTokenV2, TokenFactory 등도 동일
2. `application.yml` 의
   - `admin.private-key`
   - `admin.address`  
     값을 확인
3. 필요 시
   - 올바른 owner의 private key를 사용하거나
   - 컨트랙트 자체를 재배포


### 5.3 gasLimit / estimateGas 관련 에러

#### 증상

- BesuClient에서 tx 전송 시
  - `intrinsic gas too low`
  - 또는 예측과 다른 gasUsed 사용

#### 원인

- `eth_estimateGas` 가 실패 또는 너무 낮게 반환
- 컨트랙트 내부에서 revert가 발생하는데, estimate 단계에서는 잡히지 않는 경우

#### 대응

1. `defaultGasLimit` 값 충분히 넉넉하게 유지 (현재 3,000,000)
2. 반복적인 패턴에서
   - 실제 `gasUsed` 를 `blockchain_transactions` 로부터 통계
   - 여유분 포함해 정책 조정
3. 테스트 환경에서
   - 명시적으로 큰 `gasLimit` 을 부여해 기능 정상 동작부터 확보


### 5.4 PENDING 에서 멈춘 트랜잭션

#### 증상

- `blockchain_transactions` 에서 `transaction_status = PENDING` 이 오래 유지
- Admin 화면에서 “완료되지 않은 트랜잭션” 목록이 계속 남아 있음

#### 체크리스트

1. Besu 블록 생성 정상 여부
   - `eth_blockNumber` 증가 여부 확인
2. RPC 노드 상태
   - `eth_getTransactionReceipt(txHash)` 호출 시 응답 여부
3. `BlockchainReceiptScheduler` 동작 여부
   - `@Scheduled` 로그 확인
   - 예외로 인해 루프가 멈추지 않았는지 확인
4. 실제 체인에 해당 트랜잭션이 없는 경우
   - 노드 장애/롤백 등으로 트랜잭션이 유실되었을 수 있음
   - 운영 정책에 따라 수동으로 `FAILED` 로 마킹하거나, 재시도 트랜잭션 발송 필요


### 5.5 주소/해시 포맷 오류

#### 증상

- BesuClient 실행 시 `BlockchainException("Invalid address")`, `"Invalid hash"` 등의 메시지
- API 요청에서 잘못된 주소 형식 전달

#### 규칙

- 주소
  - 길이 42자
  - `"0x"` + 40자리 16진수
- 트랜잭션 해시
  - 길이 66자
  - `"0x"` + 64자리 16진수

#### 대응

- 컨트롤러/DTO에서 입력값 검증
- 내부에서 주소 조합 시 `StringUtils.hasText` 확인
- 테스트 시 임의 문자열이 아니라 실제 형식에 맞는 값 사용


### 5.6 DB 트랜잭션과 온체인 트랜잭션 순서 꼬임

#### 전형적인 패턴

- DB에서는 이미 상태를 “완료”로 기록했는데
- 온체인 트랜잭션이 실패하거나 네트워크 문제로 아예 보내지지 않는 상황

#### IPiece 설계 상 방어 전략

1. 주요 흐름에서
   - 온체인 트랜잭션 실패 시 `BlockchainException` 을 던져
   - 같은 서비스 메서드 내의 DB 트랜잭션까지 롤백하는 구조입니다.
2. 비동기 처리 (예: 공모 KRWT 징수)
   - 의도적으로 **DB 트랜잭션과 분리**
   - 실패해도 공모 자체를 롤백하지 않으며, 운영자가 `blockchain_transactions` 와 체인 상태를 보고 후속 조치

#### 운영 팁

- 공모/배당/2차거래와 같이 중요도가 높은 과정은
  - 가급적 동기 방식 + 실패 시 전체 롤백 구조 유지
- 비동기 정산 계열은
  - `blockchain_transactions` 를 기반으로 별도의 리컨실리레이션(대사) 배치 스크립트 준비 권장
