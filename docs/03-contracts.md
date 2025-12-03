# 03. 스마트 컨트랙트

 **스마트 컨트랙트 구조와 역할, 백엔드 연동 방식, 배포/테스트 방법, 트러블슈팅 포인트** 
---

## 1. 컨트랙트 아키텍처

### 1.1 폴더 구조

IPiece-blockchain 레포의 컨트랙트 관련 폴더 구조는 아래와 같습니다.

    contracts/
    ├─ src/
    │  ├─ KRWT.sol              # v1 현금 토큰(참고용)
    │  ├─ KRWTV2.sol            # v2 현금 토큰(프로덕션)
    │  ├─ SecurityToken.sol     # v1 종목 토큰(참고용)
    │  ├─ SecurityTokenV2.sol   # v2 종목 토큰(프로덕션)
    │  ├─ DividendDistributor.sol   # 배당 분배 컨트랙트입
    │  ├─ TokenFactory.sol      # 종목 토큰 + 배당 컨트랙트 팩토리
    │  └─ TokenSale.sol         # 온체인 공모용 보조 컨트랙트(실험용)
    │
    ├─ script/
    │  └─ Deploy.s.sol          # Foundry 배포 스크립트
    │
    └─ test/
       └─ ...                   # 단위 테스트 및 통합 테스트 코드

- 실제 프로덕션 환경에서 사용하는 컨트랙트는 **v2 버전(KRWTV2, SecurityTokenV2)**
- v1 컨트랙트(KRWT, SecurityToken)는 설계 변경 히스토리를 이해하기 위한 **참고용 코드**
- TokenSale 컨트랙트는 현재 아키텍처에서는 **주요 플로우에 사용하지 않는 옵션/실험용 컨트랙트**

### 1.2 온체인 / 오프체인 역할 구분 요약

| 계층     | 주요 구성요소                                                                 | 역할 요약                                                                                 |
|----------|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| 온체인   | KRWTV2, SecurityTokenV2, DividendDistributor, TokenFactory                   | 현금 토큰, 증권형 토큰, 배당 분배, 토큰 생성 및 배포를 담당하는 **최종 원장 계층** |
| 오프체인 | Spring Boot 백엔드(IPiece), PostgreSQL(RDS), IPiece-web(Next.js)            | 사용자/계좌/공모/2차거래/배당 선언/로그/마이페이지 등 **비즈니스 로직과 조회/집계** |

온체인은 **실제 자산과 권리의 이동**에만 집중하고, 나머지 복잡한 비즈니스 상태와 조회는 오프체인에서 담당하는 하이브리드 구조

---

## 2. 컨트랙트 역할 정의

### 2.1 KRWT(KRWTV2) – 현금 토큰

**파일 경로**: `contracts/src/KRWTV2.sol`  

KRWTV2는 **오프체인 예수금과 1:1로 대응하는 현금 토큰**입니다.

#### 2.1.1 역할

- 사용자의 원화 예수금을 온체인에서 **KRWT 토큰**으로 표현하는 역할입니다.
- 공모 참여, 2차 거래 정산, 배당 지급 등 **모든 “원화 흐름”**을 KRWT로 표현합니다.
- 오프체인의 `balance_krw` 또는 가상계좌 잔액과 **회계적으로 1:1 매핑**되도록 운영 프로세스로 관리합니다.

#### 2.1.2 특징

- ERC20 기반 토큰입니다.
- `decimals = 0` 입니다.
  - 1 KRWT = 1원 단위로 사용하기 위해 소수점 없이 설계된 토큰입니다.
  - 예시로, `cast call balanceOf` 결과가 `1000100` 이면 **그대로 1,000,100원**을 의미합니다.
- `owner` 개념이 있으며, **플랫폼 관리자 지갑**이 `owner`가 됩니다.
- `onlyOwner` 권한으로 발행, 소각, 강제이체 기능을 제어합니다.

#### 2.1.3 주요 상태 변수 예시

- `mapping(address => uint256) balances`
- `address public owner`

#### 2.1.4 주요 함수

- `mint(address to, uint256 amount)`  
  관리자 지갑이 호출하여 `to` 주소에 KRWT를 발행하는 함수입니다.  
  오프체인의 가상계좌 잔액 증가와 동시에 맞춰서 사용합니다.

- `burn(address from, uint256 amount)`  
  관리자 지갑이 호출하여 `from` 주소의 KRWT를 소각하는 함수입니다.  
  사용자의 출금, 시스템 상의 정산 등에 사용합니다.

- `transfer(address to, uint256 amount)`  
  일반적인 ERC20 전송 함수입니다.

- `forceTransfer(address from, address to, uint256 amount)`  
  관리자가 강제로 `from` 에서 `to` 로 KRWT를 이동시키는 함수입니다.  
  공모 KRWT 징수, 2차 체결 정산 등에서 사용합니다.

- `balanceOf(address account) view`  
  계정의 KRWT 잔액을 조회하는 함수입니다.

백엔드에서는 `transferKrwt`, `transferKrwtFrom`, `mintKrwt`, `burnKrwt` 등의 이름으로 위 함수들을 래핑한 서비스 메서드를 제공합니다.

---

### 2.2 SecurityToken(SecurityTokenV2) – 종목(증권형 토큰)

**파일 경로**: `contracts/src/SecurityTokenV2.sol`  

SecurityTokenV2는 **각 캐릭터 IP/프로젝트마다 발행되는 증권형 토큰**입니다.

#### 2.2.1 역할

- 공모 및 2차 거래에서 **실제 투자 대상이 되는 자산(“주식” 역할)**입니다.
- 각 상품(Product)과 1:1로 대응하며, 오프체인의 `blockchain_tokens` 테이블과 매핑됩니다.
- “누가 몇 개의 토큰을 보유하고 있는지”에 대한 **최종 원장** 역할을 합니다.

#### 2.2.2 특징

- 기본적으로 ERC20 기반이며, 현실 증권 도메인을 반영하기 위해  
  **화이트리스트, 강제이체(forceTransfer)** 기능을 포함한 **ERC-1400 유사 설계**입니다.
- `decimals = 18` 로 일반 ERC20 토큰과 동일하게 동작합니다.
- 생성 시 아래 정보를 한 번에 지정합니다.
  - `name` (예: `"MANGU Token"`)
  - `symbol` (예: `"MANGU"`)
  - `totalSupply` (초기 발행량)
  - `owner` (초기 보유자, 일반적으로 관리자 지갑)입니다.
- 일부 함수는 **onlyOwner / 관리자 전용**으로 제한됩니다.

#### 2.2.3 주요 상태 변수 예시

- `mapping(address => uint256) balances`
- `mapping(address => bool) whitelist`
- `bool public paused`
- `address public owner`

#### 2.2.4 주요 함수

- `constructor(string memory name, string memory symbol, uint256 totalSupply, address owner)`  
  토큰 메타데이터와 초기 공급량, 오너를 설정하는 생성자입니다.

- `transfer(address to, uint256 amount)`  
  화이트리스트, 정지 상태 여부 등을 체크한 뒤 전송하는 표준 ERC20 전송 함수입니다.

- `forceTransfer(address from, address to, uint256 amount)`  
  규제, 운영 상 필요할 때 관리자가 강제 이체를 수행하는 함수입니다.  
  2차 거래 체결 정산, 사고 처리, 정정 등에 사용합니다.

- `addToWhitelist(address wallet)`  
  특정 지갑을 화이트리스트에 추가하는 함수입니다.  
  토큰을 보유할 수 있는 대상 지갑을 제한하기 위한 기능입니다.

- `whitelist(address wallet) view`  
  해당 지갑이 화이트리스트에 포함되어 있는지 조회하는 함수입니다.

- (선택) `pause()`, `unpause()`  
  필요 시 거래를 일시 정지, 재개하기 위한 함수입니다.  
  실제 구현 여부는 코드 버전에 따라 다를 수 있지만, 개념적으로는 **문제 발생 시 상장 폐지, 거래정지** 등을 지원하기 위한 설계입니다.

#### 2.2.5 온/오프체인 매핑

오프체인 `blockchain_tokens` 컬럼과 아래와 같이 연결됩니다.

- `contract_address`  ↔  SecurityTokenV2 주소입니다.
- `product_id`        ↔  Product 테이블 PK입니다.
- `total_supply`      ↔  토큰 총 발행량입니다.
- `decimals`          ↔  SecurityTokenV2의 `decimals` 값입니다.

---

### 2.3 DividendDistributor – KRWT 기반 배당 분배 컨트랙트

**파일 경로**: `contracts/src/DividendDistributor.sol`  

DividendDistributor는 **특정 종목(SecurityTokenV2) 보유자들에게 KRWT 배당금을 분배하는 컨트랙트**입니다.

#### 2.3.1 역할

- 특정 상품에 대해, **배당 재원(KRWT)을 받아 투자자들에게 분할 지급**하는 기능을 담당합니다.
- 배당 계산 자체는 대부분 오프체인에서 수행하며, 온체인은 **계산 결과를 실행하는 도우미 역할**에 가깝습니다.

#### 2.3.2 작동 개념

전형적인 배당 흐름은 아래와 같습니다.

1. 관리자가 배당 재원만큼의 KRWT를 DividendDistributor 컨트랙트로 전송합니다.
2. Distributor가 내부에 설정된 토큰(SecurityTokenV2)과 보유자 정보를 기반으로,
3. 각 투자자 주소에 KRWT를 나누어 전송합니다.
4. 누가 얼마를 받았는지는 KRWT의 `Transfer` 이벤트와 Distributor의 이벤트에 온체인 로그로 남습니다.

#### 2.3.3 주요 포인트

- **최소 배당 금액**이나 **라운딩 정책**을 통해 아주 작은 단위의 배당을 조정할 수 있습니다.
- 실서비스에서는
  - 배당 계산(누가, 몇 개, 얼마 받는지)은 `holdings`, `dividends`, `dividend_payouts` 를 사용하는 오프체인 로직에서 수행하고,
  - Distributor에는 **이미 계산된 결과**를 전달하는 방식으로 사용하는 것이 안전합니다.

---

### 2.4 TokenFactory – 토큰/배당 컨트랙트 팩토리

**파일 경로**: `contracts/src/TokenFactory.sol`  

TokenFactory는 **새로운 상품이 생길 때마다 SecurityTokenV2 + DividendDistributor를 한 번에 생성하는 컨트랙트**입니다.

#### 2.4.1 역할

- 백엔드가 공모 상품을 등록할 때, 단 한 번의 온체인 호출로
  - 종목 토큰(SecurityTokenV2),
  - 해당 상품 전용 DividendDistributor
  를 함께 생성합니다.
- 생성된 컨트랙트 주소를 이벤트로 내보내 백엔드가 수신하고, DB에 저장합니다.

#### 2.4.2 주요 함수

- `createToken(string name, string symbol, uint256 totalSupply, address owner)`  
  새로운 종목 토큰과 배당 컨트랙트를 생성하는 함수입니다.  
  내부에서 SecurityTokenV2와 DividendDistributor를 생성하고, `TokenCreated` 이벤트를 발생시킵니다.

#### 2.4.3 주요 이벤트

- `event TokenCreated(string name, string symbol, address tokenAddress, address dividendAddress, uint256 totalSupply)`  
  name, symbol, tokenAddress, dividendAddress, totalSupply 정보를 담고 있는 이벤트입니다.  
  백엔드는 이 이벤트를 파싱하여 `blockchain_tokens` 및 관련 테이블에 저장합니다.

---

## 3. 이벤트 및 오프체인 연동 포인트

이 절에서는 **스마트 컨트랙트와 Spring Boot 백엔드(IPiece) 사이의 구체적인 연동 규칙**을 정리합니다.  
특히 `BesuClient`(또는 BlockchainService 계층)의 함수 맵과, 각 온체인 트랜잭션이 **어떤 DB 테이블에 어떻게 저장되는지**를 중점적으로 설명합니다.

### 3.1 공통 환경 / 역할

- **Admin EOA**  
  - 모든 write 트랜잭션은 `admin.private-key` 로 서명합니다.
  - 실제로는 Spring Boot 설정에서 `admin.private-key` 환경변수로 주입된 값입니다.

- **체인 ID**  
  - `${besu.chain-id}` 를 사용합니다. 예시로 `0x1350195` 형태로 세팅되어 있습니다.
  - 백엔드와 Besu의 `genesis.json` 설정이 반드시 일치해야 합니다.

- **가스 정책**  
  - `gasPrice = 1 wei` 로 설정합니다.
  - 가스 한도는 기본적으로 `estimateGas + 100,000` 버퍼를 사용하고, 실패 시 `${besu.tx.gas-limit.default}` 를 사용합니다.
  - Besu 노드 자체는 `--min-gas-price=0` 옵션으로 구동되어 있습니다.

- **주요 컨트랙트 주소**  
  - KRWT 컨트랙트 주소: `${krwt.contract.address}` 입니다.
  - TokenFactory 주소: `${tokenfactory.contract.address}` 입니다.
  - 각 프로젝트 토큰(SecurityTokenV2) 주소는 `blockchain_tokens` 테이블과 매핑되어 있습니다.

- **단위 규칙**  
  - KRWT는 `decimals = 0` 을 가정합니다.
  - SecurityTokenV2는 `decimals = 18` 입니다.
  - 백엔드와 프론트엔드는 조회 시 항상 `10^decimals` 로 나누어 표시합니다.

---

### 3.2 BesuClient 기준 컨트랙트 함수 맵

백엔드의 `BesuClient`(또는 유사한 역할의 컴포넌트)는 아래와 같이 컨트랙트 함수를 래핑합니다.

#### 3.2.1 KRWT 관련

- `mint(to, amount)`  
  → 서비스 메서드 `mintKrwt(to, amount)` 에서 사용합니다.

- `burn(from, amount)`  
  → 서비스 메서드 `burnKrwt(from, amount)` 에서 사용합니다.

- `transfer(to, amount)`  
  → 서비스 메서드 `transferKrwt(to, amount)` 에서 사용합니다.

- `forceTransfer(from, to, amount)`  
  → 서비스 메서드 `transferKrwtFrom(from, to, amount)` 에서 사용합니다.

- `balanceOf(address)`  
  → 조회 메서드 `getKrwtBalance(wallet)` 에서 사용합니다.

- `owner()`  
  → KRWT의 소유자를 확인하는 데 사용합니다.

#### 3.2.2 SecurityTokenV2 관련

- `transfer(to, amount)`  
  → 서비스 메서드 `transferToken(tokenAddress, to, amount)` 에서 사용합니다.

- `forceTransfer(from, to, amount)`  
  → 서비스 메서드 `transferTokenFrom(tokenAddress, from, to, amount)` 에서 사용합니다.

- `addToWhitelist(wallet)`  
  → 서비스 메서드 `addToWhitelist(tokenAddress, wallet)` 에서 사용합니다.

- `whitelist(wallet)`  
  → 조회 메서드 `isWhitelisted(tokenAddress, wallet)` 에서 사용합니다.

- `balanceOf(wallet)`  
  → 조회 메서드 `getTokenBalance(tokenAddress, wallet)` 에서 사용합니다.

#### 3.2.3 TokenFactory 관련

- `createToken(name, symbol, totalSupply, owner)`  
  → 서비스 메서드 `createTokenViaFactory(name, symbol, totalSupply, owner)` 로 래핑됩니다.

- `TokenCreated` 이벤트  
  → 로그 파싱을 통해 `tokenAddress`, `dividendAddress` 를 추출합니다.

- (선택) 조회용 함수  
  - `getTokenCount()`
  - `tokens(index)`

#### 3.2.4 DividendDistributor 관련

- 배당 집행 시 KRWT 전송을 위해 직접 Distributor를 호출하거나,  
  단순히 KRWT 전송만 사용하는 방식 중 하나로 구현될 수 있습니다.
- 이벤트, 함수 시그니처에 따라 `executeDueDividends` 등과 연동되며,  
  `BlockchainTransaction(type=DIVIDEND)` 기록과 매핑됩니다.

---

### 3.3 온체인 write 호출별 입력 / 출력 / 오프체인 기록

이 절에서는 **각 write 트랜잭션이 어떤 API/서비스에서 호출되고, 어떤 테이블에 어떻게 기록되는지**를 형태별로 정리합니다.

#### 3.3.1 KRWT 발행 – mintKrwt(to, amount)

- API / 서비스 입력  
  - Admin API: 사용자의 가상계좌에 KRWT를 충전하는 요청입니다.  
    예시로 `POST /v1/admin/krwt/mint { userId, amount }` 형태를 가정합니다.

- 온체인 호출  
  - 컨트랙트: KRWTV2입니다.
  - 함수: `mint(to, amount)` 입니다.
  - 서명자: Admin EOA입니다.

- DB 기록  
  - `KrwtOperation` 엔티티에 한 건을 생성합니다.
    - `type = MINT` 입니다.
    - `status = PENDING` 입니다.
    - `txHash`, `userId`, `walletAddress`, `amount` 를 기록합니다.
  - 가상계좌(`VirtualAccount`) 및 `VirtualAccountJournal`에는 **트랜잭션 성공 후** 잔액 증가를 반영합니다.

#### 3.3.2 KRWT 소각 – burnKrwt(from, amount)

- API / 서비스 입력  
  - Admin API: 사용자의 KRWT를 회수하거나 출금 처리하는 요청입니다.

- 온체인 호출  
  - 컨트랙트: KRWTV2입니다.
  - 함수: `burn(from, amount)` 입니다.

- DB 기록  
  - `KrwtOperation` 에 `type = BURN` 으로 기록합니다.
  - `status = PENDING` 에서 리시트 확인 후 `SUCCESS` 또는 `FAILED` 로 변경합니다.
  - `VirtualAccount`, `VirtualAccountJournal`에서 잔액 감소를 반영합니다.

#### 3.3.3 KRWT 전송 – transferKrwt(to, amount)

- 주요 사용 케이스  
  - 관리자 → 사용자 배당 지급입니다.
  - 관리자 → 사용자 충전, 보정입니다.

- 온체인 호출  
  - 컨트랙트: KRWTV2입니다.
  - 함수: `transfer(to, amount)` 입니다.

- DB 기록  
  - `BlockchainTransaction` 엔티티에 한 건을 생성합니다.
    - `type = DIVIDEND` 또는 `TRANSFER` 입니다.
    - `status = PENDING` 입니다.
    - `from = adminWallet`, `to = userWallet`, `tokenAddress = KRWT`, `amount` 를 기록합니다.
  - 배당의 경우 `DividendPayout` 또는 관련 엔티티에 연결합니다.

#### 3.3.4 KRWT 강제 전송 – transferKrwtFrom(from, to, amount)

- 주요 사용 케이스  
  - 공모 KRWT 징수입니다.
  - 2차 거래 정산에서 매수자 → 매도자 현금 이동입니다.

- 온체인 호출  
  - 컨트랙트: KRWTV2입니다.
  - 함수: `forceTransfer(from, to, amount)` 입니다.

- DB 기록  
  - `BlockchainTransaction` 엔티티에
    - `type = TRANSFER` 입니다.
    - `status = PENDING` 입니다.
    - `from = buyerWallet`, `to = sellerWallet` 또는 `adminWallet` 등 실제 흐름을 기록합니다.
  - 공모 징수의 경우 Investment 또는 Offering 관련 엔티티와 연결합니다.

#### 3.3.5 종목 토큰 전송 – transferToken(contract, to, amount)

- 주요 사용 케이스  
  - 공모 배정 시, 관리자 지갑 → 투자자 지갑 토큰 이동입니다.

- 온체인 호출  
  - 컨트랙트: SecurityTokenV2입니다.
  - 함수: `transfer(to, amount)` 입니다.

- DB 기록  
  - `BlockchainTransaction` 엔티티에
    - `type = TRANSFER` 입니다.
    - `tokenAddress = product.tokenContractAddress` 입니다.
    - `userId`, `investmentId` 등을 참조로 기록합니다.
  - `holdings` 테이블의 보유 수량과 평균 단가를 갱신합니다.

#### 3.3.6 종목 토큰 강제 전송 – transferTokenFrom(contract, from, to, amount)

- 주요 사용 케이스  
  - 2차 거래 체결 후, 매도자 → 매수자 토큰 이동입니다.

- 온체인 호출  
  - 컨트랙트: SecurityTokenV2입니다.
  - 함수: `forceTransfer(from, to, amount)` 입니다.

- DB 기록  
  - `BlockchainTransaction` 엔티티에
    - `type = TRANSFER` 입니다.
    - `from = sellerWallet`, `to = buyerWallet` 입니다.
  - `holdings` 테이블에서 매수, 매도 양측의 수량을 갱신합니다.

#### 3.3.7 화이트리스트 등록 – addToWhitelist(contract, wallet)

- 주요 사용 케이스  
  - 공모 참여 시, 해당 종목 SecurityTokenV2의 보유 허용 대상에 투자자를 추가하는 작업입니다.

- 온체인 호출  
  - 컨트랙트: SecurityTokenV2입니다.
  - 함수: `addToWhitelist(wallet)` 입니다.

- DB 기록  
  - `Investment` 엔티티에 `whitelistTxHash` 를 기록합니다.
  - 필요 시 `BlockchainTransaction` 에 별도 유형으로 저장할 수 있습니다.

#### 3.3.8 토큰 생성 – createTokenViaFactory(name, symbol, totalSupply)

- 주요 사용 케이스  
  - 새로운 상품 공모를 등록할 때 종목 토큰과 배당 컨트랙트를 함께 생성하는 작업입니다.

- 온체인 호출  
  - 컨트랙트: TokenFactory입니다.
  - 함수: `createToken(name, symbol, totalSupply, owner)` 입니다.
  - 이벤트: `TokenCreated` 입니다.

- DB 기록  
  - `BlockchainToken` 엔티티에
    - `contractAddress = tokenAddress` 입니다.
    - `dividendContractAddress = dividendAddress` 입니다.
    - `name`, `symbol`, `totalSupply`, `ownerUserId`, `txHash`, `status = DEPLOYED` 등을 기록합니다.
  - 필요하다면 `BlockchainTransaction(type=TOKEN_CREATION)` 으로도 별도 기록합니다.

---

### 3.4 주요 비즈니스 흐름별 상세

아래는 **“API 입력 → DB 조회/검증 → 호출 컨트랙트 함수 및 파라미터 → 반환값(txHash/receipt) → 오프체인 저장 필드”** 순으로 정리한 흐름입니다.

#### 3.4.1 프로젝트 토큰 생성

1. API 입력  
   - `POST /v1/admin/tokens`  
   - `CreateTokenRequest { name, symbol, totalSupply, faceValue }` 입니다.

2. 오프체인 검증  
   - Admin 권한을 확인합니다.
   - `totalSupply > 0`, `name`, `symbol` 형식 유효성을 검사합니다.

3. 온체인 호출  
   - `TokenFactory.createToken(name, symbol, totalSupply, ownerAddress)` 를 호출합니다.
   - 서명자는 Admin EOA입니다.

4. 반환값  
   - `txHash` 를 즉시 반환합니다.
   - `TokenCreated` 이벤트 로그를 파싱하여 `tokenAddress`, `dividendAddress` 를 얻습니다.

5. DB 저장  
   - `BlockchainToken` 엔티티에
     - `productId`, `name`, `symbol`, `totalSupply`, `faceValue`, `ownerUserId`, `contractAddress`, `dividendContractAddress`, `txHash` 를 저장합니다.
   - 필요 시 `BlockchainTransaction(type=TOKEN_CREATION)` 으로도 기록합니다.

#### 3.4.2 공모 참여(투자)

1. API 입력  
   - `POST /v1/investments`  
   - `InvestmentRequest { projectId, amountKrwt, tokenAmount }` 입니다.

2. 오프체인 검증  
   - 유저, 지갑 존재 여부를 확인합니다.
   - 공모 상태, 투자 한도, 잔액을 검증합니다.
   - `product.tokenContractAddress` 존재 여부를 확인합니다.

3. 온체인 호출  
   1) 화이트리스트 등록입니다.  
      - `SecurityTokenV2.addToWhitelist(userWallet)` 를 호출합니다.  
      - `whitelistTxHash` 를 저장합니다.  

   2) 토큰 전송입니다.  
      - `SecurityTokenV2.transfer(userWallet, tokenAmount)` 를 호출합니다.  
      - `transferTxHash` 를 저장합니다.

4. DB 저장  
   - `Investment` 엔티티에
     - 초기 상태 `status = PENDING` 로 저장합니다.
     - `whitelistTxHash`, `transferTxHash` 를 함께 저장합니다.
   - `BlockchainTransaction(type=TRANSFER)` 엔티티에
     - `from = adminWallet`, `to = userWallet`, `tokenAddress = tokenContract`, `amount = tokenAmount`, `investmentId` 연결 정보를 기록합니다.
   - 이후 Receipt 스케줄러가 트랜잭션을 조회하여 `SUCCESS` 또는 `FAILED` 로 상태를 갱신합니다.

#### 3.4.3 공모 → 2차거래 전환

1. API 입력  
   - `POST /v1/admin/products/{productId}/enable-offering`  
   - `AdminEnableSecondaryTradingRequest { confirm: true }` 입니다.

2. 오프체인 집계  
   - 공모 구독 정보에서 계좌별 `quantity`, `offeringPrice` 를 집계합니다.

3. 온체인 호출  
   - 계좌마다 순회하면서
     - `addToWhitelist(tokenAddress, wallet)` 를 호출합니다.
     - `transferToken(tokenAddress, wallet, quantity)` 를 호출합니다.

4. DB 저장  
   - 각 계좌에 대해 `BlockchainTransaction` 을 생성합니다.
   - `holdings` 테이블에서 상품 보유 수량과 평단가를 세팅합니다.
   - 공모 구독 관련 테이블을 정리하고, `product.status` 를 `OFFERING → TRADE` 로 변경합니다.

#### 3.4.4 2차거래 체결 정산

1. 입력  
   - 내부 서비스 호출: `settleTradeOnChain(buyOrder, sellOrder, qty, price)` 입니다.

2. 오프체인 검증  
   - 주문 상태가 유효하고 체결 가능한지 확인합니다.
   - 매수자, 매도자 지갑 주소, KRWT 잔액, 토큰 잔액을 검사합니다.

3. 온체인 호출  
   - 1) 종목 토큰 이동입니다.  
     - `SecurityTokenV2.forceTransfer(sellerWallet, buyerWallet, qty)` 를 호출합니다.  

   - 2) KRWT 이동입니다.  
     - `KRWTV2.forceTransfer(buyerWallet, sellerWallet, qty * price)` 를 호출합니다.

4. DB 저장  
   - 두 건의 `BlockchainTransaction(type=TRANSFER)` 를 생성합니다.
     - 첫 번째는 토큰 이동입니다.
     - 두 번째는 KRWT 이동입니다.
   - `trades`, `order_book` 상태를 체결 완료로 갱신합니다.
   - `holdings` 와 `VirtualAccount` 를 갱신합니다.

#### 3.4.5 공모 KRWT 징수(비동기)

1. 입력  
   - 공모 배정이 확정된 후 비동기 작업에서 `transferKrwtForOffering(userId, walletAddress, totalPrice)` 를 호출합니다.

2. 온체인 호출  
   - `KRWTV2.forceTransfer(userWallet, adminWallet, totalPrice)` 를 호출합니다.

3. DB 저장  
   - `BlockchainTransaction(type=TRANSFER)` 엔티티에
     - `from = userWallet`, `to = adminWallet`, `amount = totalPrice` 를 기록합니다.
   - Receipt 확인 후 `status = SUCCESS` 가 되면
     - 사용자의 KRWT, 가상계좌 잔액을 조정하고
     - 관련 Investment, Offering 상태를 갱신합니다.

#### 3.4.6 배당 집행

1. 배당 선언(오프체인)  
   - Admin이 `recordDate`, `payoutDate`, `totalAmount` 를 입력합니다.
   - 백엔드는 `dividends`, `dividend_payouts` 엔티티를 생성합니다.

2. 스케줄링  
   - `allocateDueDividends` 가 `recordDate` 기준으로 배당 대상, 금액을 계산합니다.

3. 온체인 호출 – executeDueDividends  
   - `executeDueDividends` 또는 유사 메서드에서
     - 각 `DividendPayout` 에 대해 `KRWTV2.transfer(userWallet, amount)` 를 호출합니다.

4. DB 저장  
   - 각 호출에 대해 `BlockchainTransaction(type=DIVIDEND)` 를 생성합니다.
   - 성공 시
     - `VirtualAccount` 잔액을 증가시키고
     - `VirtualAccountJournal` 에 내역을 기록합니다.
     - `DividendPayout` 및 `Dividends` 상태를 `PAID` 로 변경합니다.
   - 실패 시
     - `status = FAILED` 와 에러 메시지를 기록합니다.

#### 3.4.7 KRWT 발행/소각 관리

- Admin이 사용자 가상계좌에 KRWT를 발행하거나, 소각하는 기능입니다.
- `mintKrwt`, `burnKrwt` 를 통해 온체인 호출을 수행합니다.
- `KrwtOperation`, `VirtualAccount`, `VirtualAccountJournal` 을 통해 오프체인에서도 잔액 변화를 관리합니다.

---

### 3.5 조회형 기능

백엔드는 다음과 같은 조회용 래퍼를 제공합니다.

- `getKrwtBalance(wallet)`  
  - `KRWTV2.balanceOf(wallet)` 호출 결과입니다.

- `getTokenBalance(contract, wallet)`  
  - `SecurityTokenV2.balanceOf(wallet)` 호출 결과입니다.

- `isWhitelisted(contract, wallet)`  
  - `SecurityTokenV2.whitelist(wallet)` 호출 결과입니다.

- `getTransactionReceipt(txHash)`  
  - `web3j.ethGetTransactionReceipt(txHash)` 로 조회합니다.
  - `status`, `blockNumber`, `logs` 등을 맵 형태로 반환합니다.

- `getContractInfo()`  
  - KRWT, TokenFactory 등의 `owner` 와 주요 파라미터를 조회하는 기능입니다.

---

## 4. 배포 및 테스트 방법

### 4.1 Foundry 환경 설정

배포 서버(예: `deploy` 호스트)에 Foundry를 설치한 뒤 아래와 같이 환경변수를 설정합니다.

    export RPC_URL=http://172.16.4.60:8545     # Besu RPC VIP입니다.
    export PRIVATE_KEY=0x...                   # Admin EOA 프라이빗 키입니다.
    export CHAIN_ID=0x1350195                  # genesis.json 과 동일한 chainId입니다.

### 4.2 빌드 및 테스트

    cd contracts

    # 의존성 설치(필요 시)
    forge install

    # 컴파일
    forge build

    # 단위 테스트
    forge test -vv

테스트 내용은 아래와 같이 구성됩니다.

- KRWTV2 기본 동작입니다.  
  mint, burn, transfer, forceTransfer 로직입니다.
- SecurityTokenV2 동작입니다.  
  transfer, forceTransfer, whitelist, pause 등입니다.
- DividendDistributor 배당 분배 로직입니다.
- TokenFactory 토큰, 배당 컨트랙트 생성 및 `TokenCreated` 이벤트 검증입니다.

### 4.3 배포 스크립트(Deploy.s.sol)

`contracts/script/Deploy.s.sol` 에 배포 스크립트가 정의되어 있습니다.

    cd contracts

    forge script script/Deploy.s.sol:Deploy \
      --rpc-url "$RPC_URL" \
      --private-key "$PRIVATE_KEY" \
      --broadcast \
      --chain-id "$CHAIN_ID"

배포 스크립트는 일반적으로 다음을 수행합니다.

1. KRWTV2 배포입니다.
2. TokenFactory 배포입니다.
3. (옵션) 예시 SecurityTokenV2, DividendDistributor 생성입니다.
4. `console.log` 또는 이벤트를 통해 다음 정보를 출력합니다.
   - KRWTV2 주소입니다.
   - TokenFactory 주소입니다.
   - 예시 토큰, 배당 컨트랙트 주소입니다.

출력된 주소는 **백엔드 환경변수(.env, application.yml)** 와 **DB(blockchain_tokens)** 에 반영합니다.

### 4.4 cast를 이용한 수동 검증

배포 후 간단한 수동 검증을 위해 `cast` 를 사용합니다.

    export RPC_URL=http://172.16.4.60:8545
    export KRWT=0x...      # 배포된 KRWTV2 주소입니다.
    export TOKEN=0x...     # 특정 SecurityTokenV2 주소입니다.
    export USER=0x...      # 사용자 지갑 주소입니다.

    # KRWT 잔액 조회
    cast call $KRWT "balanceOf(address)(uint256)" $USER --rpc-url $RPC_URL

    # SecurityTokenV2 잔액 조회
    cast call $TOKEN "balanceOf(address)(uint256)" $USER --rpc-url $RPC_URL

    # KRWT owner 확인
    cast call $KRWT "owner()(address)" --rpc-url $RPC_URL

    # 체인 ID 확인
    cast rpc eth_chainId --rpc-url $RPC_URL

- KRWT는 `decimals = 0` 이므로, 예시로 결과가 `1000100` 이면 **1,000,100원**을 의미합니다.
- SecurityTokenV2는 `decimals = 18` 이므로, 프론트와 백엔드는 결과를 `10^18` 로 나누어 표시해야 합니다.

---

## 5. 트러블슈팅

온체인, 오프체인 하이브리드 구조에서는 **체인 설정, 컨트랙트 권한, decimals 처리, DB 정합성** 등에서 문제가 발생하기 쉽습니다.  
아래는 실제 트러블슈팅 경험을 기반으로 정리한 주요 포인트입니다.

### 5.1 decimals 혼동

- 문제 상황입니다.  
  KRWT와 SecurityTokenV2의 잔액이 화면에서 이상하게 보이거나,  
  공모, 2차 거래, 배당 금액이 100배, 10^18배씩 차이가 나는 현상이 발생합니다.

- 원인입니다.  
  - KRWT는 `decimals = 0` 입니다.
  - SecurityTokenV2는 `decimals = 18` 입니다.
  - 프론트와 백엔드에서 이를 고려하지 않고 동일한 방식으로 나누거나,  
    DB의 `decimals` 값을 무시하고 처리할 때 문제가 발생합니다.

- 대응 방법입니다.  
  - `blockchain_tokens.decimals` 컬럼을 항상 참조하여 표시 단위를 변환합니다.
  - KRWT는 소수점 없이 정수 그대로 원 단위로 표시합니다.
  - SecurityTokenV2는 온체인 값 / `10^18` 로 나누어 표시합니다.

### 5.2 OWNER와 관리자 지갑 불일치

- 문제 상황입니다.  
  KRWT mint, burn, SecurityTokenV2 addToWhitelist, forceTransfer 호출 시 `revert` 가 발생합니다.

- 원인입니다.  
  컨트랙트의 `owner()` 주소와 백엔드에서 사용하는 `admin.private-key` 가 서로 다른 경우입니다.

- 대응 방법입니다.  
  1. `cast call $KRWT "owner()(address)"` 로 KRWT의 owner를 확인합니다.  
  2. 백엔드 설정의 `admin.private-key` 에 해당하는 주소와 일치하는지 비교합니다.  
  3. 필요하다면 새로 배포하거나, 권한 이전 함수가 있을 경우 `transferOwnership` 을 통해 조정합니다.

- 체크 포인트입니다.  
  새로 체인을 초기화하거나 컨트랙트를 재배포했을 때 가장 먼저 owner를 확인하는 습관을 가지는 것이 좋습니다.

### 5.3 이벤트, DB 정합성 불일치

- 문제 상황입니다.  
  온체인에서는 트랜잭션이 성공했지만 DB 상태가 반영되지 않았거나,  
  트랜잭션이 실패했는데도 DB는 성공으로 표시되는 경우가 발생합니다.

- 원인입니다.  
  - `BlockchainTransaction.status` 를 업데이트하는 Receipt 스케줄러가 오류로 멈춘 경우입니다.
  - txHash 저장 이전에 애플리케이션 예외가 발생한 경우입니다.

- 대응 방법입니다.  
  - `BlockchainTransaction` 중 `status = PENDING` 인 레코드를 조회합니다.
  - 각 `txHash` 에 대해 수동으로 `getTransactionReceipt` 를 호출합니다.
  - Receipt 결과에 따라 DB를 `SUCCESS`, `FAILED` 로 수동 업데이트합니다.
  - 필요하다면 재처리 플로우(재시도, 롤백) 정책을 별도 문서로 정리합니다.

### 5.4 chainId, gas 설정 오류

- 문제 상황입니다.  
  트랜잭션이 계속 `pending` 상태에서 사라지지 않거나, 즉시 `invalid transaction` 오류가 발생합니다.

- 원인입니다.  
  - 백엔드의 `besu.chain-id` 와 genesis의 chainId가 불일치합니다.
  - gasLimit 설정이 너무 낮아서 항상 OOG(Out of Gas) 로 `revert` 됩니다.

- 대응 방법입니다.  
  - `cast rpc eth_chainId` 로 실제 체인의 chainId를 확인합니다.
  - `application.yml` 설정의 chainId와 일치하도록 조정합니다.
  - 기본적으로 `estimateGas + buffer` 전략을 사용합니다.
  - Besu 로그에서 OOG 관련 메시지가 있는지 확인합니다.

### 5.5 forceTransfer 오용

- 문제 상황입니다.  
  체결 정산이나 공모 징수 과정에서 잘못된 주소로 강제이체가 발생하여  
  원장 전체를 되돌리기 어려운 상황이 발생할 수 있습니다.

- 원인입니다.  
  `from`, `to` 주소를 반대로 넣거나, 검증 로직 없이 호출하는 경우입니다.

- 대응 방법입니다.  
  - `forceTransfer` 를 호출하기 전
    - 주문, 투자, 배당 엔티티와의 매핑이 정확한지,
    - `from` 이 실제 보유자인지, `to` 가 올바른 대상인지
    를 철저히 검증합니다.
  - 운영 단계에서는 강제이체를 최소화하고, 필요하다면 별도의 승인 절차를 거치는 정책을 권장합니다.

### 5.6 중복 트랜잭션 및 재실행 이슈

- 문제 상황입니다.  
  같은 공모, 체결, 배당에 대해 중복으로 온체인 트랜잭션이 발생합니다.

- 원인입니다.  
  애플리케이션 레벨에서 **idempotency** 처리가 부족한 경우입니다.

- 대응 방법입니다.  
  - 각 비즈니스 플로우에 **idempotency key** 또는 유니크한 자연키를 두고,  
    이미 존재하는 `BlockchainTransaction` 이 있는지 확인한 후 재호출을 방지합니다.
  - `txHash`, `businessId`(예: investmentId, dividendId)를 유니크하게 관리합니다.

---

이 문서는 IPiece 스마트 컨트랙트 레이어가 **어떤 구조로 설계되어 있고, 백엔드와 DB와 어떻게 연결되어 있으며, 실제 비즈니스 플로우에서 무엇을 보장하는지**를 설명하기 위해 작성된 문서입니다.  
온체인, 오프체인 구조와 인프라, 백엔드 연동에 대한 자세한 내용은 다음 문서를 함께 참고하면 좋습니다.

- 01. 기획: `docs/01-planning.md` 입니다.
- 02. 인프라: `docs/02-server-besu.md` 입니다.
- 04. 백엔드 연동: `docs/04-backend-integration.md` 입니다.
