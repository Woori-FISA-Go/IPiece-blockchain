<!-- docs/03-contracts.md -->

# 03. 스마트 컨트랙트

이 문서는 IPiece 온체인 영역의 **스마트 컨트랙트 구조와 역할,  
배포/테스트 방법**을 정리한다.

---

## 1. 폴더 구조

    contracts/
    ├─ src/
    │  ├─ KRWT.sol              # v1 현금 토큰(참고용)
    │  ├─ KRWTV2.sol            # v2 현금 토큰(실사용)
    │  ├─ SecurityToken.sol     # v1 종목 토큰(참고용)
    │  ├─ SecurityTokenV2.sol   # v2 종목 토큰(실사용)
    │  ├─ DividendDistributor.sol
    │  ├─ TokenFactory.sol
    │  └─ TokenSale.sol         # 토큰 판매용 보조 컨트랙트
    ├─ script/
    │  └─ Deploy.s.sol          # Foundry 배포 스크립트
    └─ test/
       └─ ...                   # 단위 테스트

- 실제 프로덕션에서 사용하는 것은 **V2 버전(KRWTV2, SecurityTokenV2)** 기준.
- v1 컨트랙트는 설계 변경 히스토리를 이해하기 위한 참고용 코드.

---

## 2. 주요 컨트랙트 역할

### 2.1 KRWTV2 – 현금 토큰

파일: contracts/src/KRWTV2.sol

- 역할
  - 오프체인에서 관리되는 원화 예수금과 1:1로 대응하는 **현금 토큰**
  - 배당 지급, 공모 결제, 2차 거래 결제 등에 사용 가능
- 특징
  - ERC20 기반이지만 **decimals = 0**
    - 1 KRWT = 1원처럼 “원 단위”로 사용하기 위해 설계
  - 초기 발행량(cap) 설정 및 소유자(owner) 개념
  - onlyOwner 권한으로 mint/burn 가능 (운영 정책에 따라 제약)
- 주요 함수(개념)
  - mint(address to, uint256 amount) – KRWT 발행
  - burn(address from, uint256 amount) – KRWT 소각
  - transfer, transferFrom – 일반 ERC20 전송

> 오프체인의 balance_krw 혹은 예수금 계좌와  
> KRWT 총량이 **회계적으로 맞도록 운영 프로세스에서 관리**한다.

### 2.2 SecurityTokenV2 – 종목 토큰

파일: contracts/src/SecurityTokenV2.sol

- 역할
  - 각 캐릭터 IP/프로젝트 별로 발행되는 **증권형 토큰**
  - 공모/2차 거래의 “주식” 역할
- 특징
  - ERC20 상속
  - decimals = 18 (일반 ERC20 토큰과 동일)
  - 생성 시
    - 토큰 이름(name)
    - 심볼(symbol)
    - 초기 공급량(initial supply)
    - 소유자(owner)
    를 한 번에 지정
- 주요 함수
  - constructor(...) – 토큰 메타데이터 및 초기 발행량 설정
  - transfer, transferFrom – 지갑 간 소유권 이동
- 온/오프체인 매핑
  - 오프체인 테이블 blockchain_tokens 의
    - contract_address
    - product_id
    - total_supply
    와 연결된다.

### 2.3 DividendDistributor – 배당 분배 컨트랙트

파일: contracts/src/DividendDistributor.sol

- 역할
  - 특정 SecurityTokenV2 종목에 대해,  
    KRWT 기반 배당을 온체인에서 분배하는 도우미.
- 설계 개념
  - 배당 대상 토큰(종목)의 총 발행량과  
    개별 주소의 보유량에 따라 KRWT를 나누어 주는 구조.
  - 매우 작은 단위의 배당(잔돈)을 줄이기 위해  
    최소 배당 금액(MIN_TOTAL_DIVIDEND) 등을 설정 가능.
- 사용 패턴 예시
  1. 관리자가 KRWT를 Distributor 컨트랙트로 전송
  2. Distributor가 내부 로직에 따라  
     SecurityTokenV2 보유자들에게 KRWT를 나누어 전송
  3. 온체인에 “누가 얼마 받았는지”가 트랜잭션 로그로 남음
- 주의
  - 실제 배당 대상/금액 계산은 보통 오프체인(holdings 기반)에서 수행하고,  
    온체인은 그 결과를 실행하는 역할로 한정하는 게 운영상 안전하다.

### 2.4 TokenFactory – 토큰/배당 컨트랙트 팩토리

파일: contracts/src/TokenFactory.sol

- 역할
  - 하나의 트랜잭션으로
    - SecurityTokenV2 (종목 토큰)
    - DividendDistributor (해당 종목의 배당 컨트랙트)
    를 함께 생성해주는 팩토리.
- 외부에서 보는 포인트
  - 백엔드는 공모 상품 등록 시
    - createTokenAndDistributor(...) 같은 함수를 호출해
    - 새로운 종목 토큰 + 배당 디스트리뷰터를 한 번에 생성
  - 이벤트(Event)를 통해
    - 생성된 토큰 주소
    - Distributor 주소
    를 읽어서 blockchain_tokens 등에 저장.

### 2.5 TokenSale (선택적)

파일: contracts/src/TokenSale.sol

- 공모 참여를 완전히 온체인에서 처리하고 싶을 때 사용할 수 있는  
  “판매/청약”용 보조 컨트랙트.
- 현재 IPiece에서는 백엔드 비즈니스 로직과 DB를 중심으로 공모를 관리하고,  
  온체인은 실제 토큰 이동/결제에 집중하는 설계이므로  
  TokenSale은 옵션/실험용에 가깝다.

---

## 3. 배포 스크립트(Foundry)

### 3.1 Deploy.s.sol 개요

파일: contracts/script/Deploy.s.sol

- 환경 변수 예시
  - RPC_URL – Besu RPC URL (VIP 사용)
  - PRIVATE_KEY – 배포자 지갑의 프라이빗 키
  - CHAIN_ID – Besu 체인의 chainId
- 주요 역할
  - KRWTV2 배포
  - TokenFactory 배포
  - (필요 시) 예시 종목, Distributor 생성

### 3.2 배포 명령 예시

    cd contracts
    
    # 1) 빌드
    forge build
    
    # 2) 테스트
    forge test
    
    # 3) 배포 (예시)
    forge script script/Deploy.s.sol:Deploy \
      --rpc-url $RPC_URL \
      --private-key $PRIVATE_KEY \
      --broadcast \
      --chain-id $CHAIN_ID

배포가 완료되면, 스크립트 내 console.log 출력 등을 통해

- KRWTV2 주소
- TokenFactory 주소
- 기본 종목/Distributor 주소

를 확인하고, 이를 백엔드/환경 변수/DB에 반영한다.

---

## 4. 테스트 & 검증

### 4.1 forge test

    cd contracts
    forge test -vv

- 토큰 기본 동작
  - mint/burn/transfer
- Distributor 배당 분배 로직
- Factory를 통한 생성/이벤트 검증

### 4.2 cast를 이용한 수동 검증

    export RPC_URL=http://172.16.4.60:8545
    export KRWT=0x...   # 배포된 KRWTV2 주소
    export USER=0x...   # 사용자 지갑 주소
    
    cast call $KRWT "balanceOf(address)(uint256)" $USER --rpc-url $RPC_URL

- KRWTV2는 decimals = 0 이므로,  
  결과 값 1000100 이라면 **정수 그대로 1,000,100원**을 의미한다.

---

## 5. 온체인 기능과 컨트랙트의 관계

IPiece에서 **온체인이 담당하는 기능은 전부 스마트 컨트랙트에 의해 가능**해진다.

- 현금 토큰 발행/이체 → KRWTV2
- 종목 토큰 발행/이체 → SecurityTokenV2
- 배당 집행 → DividendDistributor
- 상품별 토큰/배당 컨트랙트 생성 → TokenFactory

블록체인은 단지 이 컨트랙트들의 상태와 트랜잭션을 영구히 저장/검증할 뿐이고,  
“무엇을 어떻게 할 수 있는지”는 오로지 **컨트랙트 코드가 정의**한다.

---

## 6. 트러블슈팅 포인트

### 6.1 decimals 혼동

- KRWTV2는 decimals = 0, SecurityTokenV2는 18
- 백엔드/프론트에서
  - 표시 단위, 나누기(10^decimals) 계산을 잘못하면
  - 잔고가 100배/10^18배 이상 크게/작게 보이는 문제가 발생.
- 대응
  - blockchain_tokens.decimals 컬럼을 활용해서  
    화면/로직에서 항상 10^decimals로 나눠서 처리.

### 6.2 OWNER와 관리자 지갑 불일치

- KRWTV2의 owner() 주소가 mint/burn 권한을 가진 주체.
- 배당/입출금 로직에서 사용하는 “관리자 지갑 주소”가  
  컨트랙트의 owner와 다르면 트랜잭션이 revert 될 수 있음.
- 배포 후 반드시

      cast call $KRWT "owner()(address)" --rpc-url $RPC_URL

  로 owner를 확인하고, 백엔드 설정과 맞추어야 한다.

### 6.3 Distributor 사용 시 예상과 다른 배당 금액

- 최소 배당 금액, 라운딩 처리에 의해
  - 일부 주소는 0 KRWT를 받거나
  - 디테일한 배당금이 기대와 조금 다를 수 있다.
- 실서비스에서는
  - 배당 금액 계산을 오프체인에서 먼저 정확히 계산하고,
  - 온체인에서는 그 결과를 그대로 반영하는 방향이 안정적이다.
