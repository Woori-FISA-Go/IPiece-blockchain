# IPiece 블록체인 스마트 컨트랙트

## 🚀 프로젝트 개요

IPiece는 지적 재산(IP) 권리를 토큰화하는 STO(Security Token Offering) 플랫폼입니다. 이 저장소는 플랫폼의 핵심 스마트 컨트랙트들을 포함하고 있습니다.

**아키텍처:**
*   **프론트엔드/백엔드:** AWS 클라우드 (Spring Boot, PostgreSQL, Kafka)
*   **블록체인:** 온프레미스 Hyperledger Besu 프라이빗 네트워크 (IBFT2 합의)
*   **트랜잭션 처리:** AWS와 Besu 간 Kafka를 통한 비동기 통신

## 📦 주요 스마트 컨트랙트

| 컨트랙트 이름        | 설명                                                                                                                                                                                                                                                                                                   |
| :------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `KRWT.sol`           | IPiece 생태계의 기축 통화로 사용되는 원화(KRW) 페그(peg) 스테이블 코인입니다. (18 소수점)                                                                                                                                                                                                                           |
| `SecurityToken.sol`  | IP에 대한 지분을 나타내는 증권형 토큰입니다. 모든 거래는 화이트리스트에 등록된 참여자에게만 허용됩니다. (0 소수점)                                                                                                                                                                                                  |
| `DividendDistributor.sol` | `SecurityToken` 보유자들에게 `KRWT`로 배당금을 분배하는 컨트랙트입니다. Push 방식을 사용하며, `TokenFactory`에 의해 생성됩니다.                                                                                                                                                                                  |
| `TokenFactory.sol`   | 새로운 IP 상품(즉, `SecurityToken`과 `DividendDistributor` 컨트랙트 세트)을 생성하는 팩토리 컨트랙트입니다. 컨트랙트 생성 및 소유권 지정을 자동화합니다.                                                                                                                                                        |
| `TokenSale.sol`      | 새로 발행된 `SecurityToken`을 `KRWT`와 교환하여 판매하는 컨트랙트입니다. Soft/Hard Cap, KYC 화이트리스트 기반의 토큰 판매 로직을 포함합니다.                                                                                                                                                               |

## 🛠️ 개발 환경 설정

### 전제 조건

*   **Foundry:** 스마트 컨트랙트 개발, 테스트, 배포 프레임워크 ([설치 가이드](https://book.getfoundry.sh/getting-started/installation))
*   **`jq`:** `deploy.sh` 스크립트에서 JSON 파싱을 위해 사용됩니다. ([설치 가이드](https://jqlang.github.io/jq/download/))

### 프로젝트 초기화

1.  저장소를 클론합니다:
    ```bash
    git clone https://github.com/Woori-FISA-Go/IPiece-blockchain.git
    cd IPiece-blockchain
    ```
2.  Foundry 의존성을 설치합니다:
    ```bash
    forge install --root contracts
    ```
3.  Foundry 프로젝트를 빌드합니다:
    ```bash
    forge build --root contracts
    ```

## 🧪 테스트

모든 컨트랙트 테스트를 실행하려면 `contracts` 디렉토리에서 다음 명령어를 사용하세요:

```bash
forge test --root contracts
```

## ⚙️ 컨트랙트 배포 (Hyperledger Besu 네트워크)

### 1. `.env` 파일 설정

프로젝트 루트(`~/IPiece-blockchain`)에 `.env` 파일을 생성하고, 배포 스크립트가 사용할 환경 변수들을 설정합니다.

> **개인키 및 주소 생성:** 메타마스크(MetaMask)를 사용하여 배포자(Deployer) 및 관리자(Admin) 지갑을 생성하고 해당 주소와 개인키를 안전하게 관리하세요.

```ini
# Network
BESU_RPC_URL=http://<YOUR_BESU_VIP_ADDRESS>:8545 # 예: http://172.16.4.60:8545
BESU_CHAIN_ID=<YOUR_BESU_CHAIN_ID>               # 예: 20251029

# Deployer (배포 트랜잭션을 발생시킬 계정)
DEPLOYER_ADDRESS=0x...
DEPLOYER_PRIVATE_KEY=...

# Admin (배포된 컨트랙트들의 최종 소유자가 될 계정)
ADMIN_ADDRESS=0x...
ADMIN_PRIVATE_KEY=...
```

### 2. 배포 스크립트 실행

`.env` 파일 작성을 완료한 후, 프로젝트 루트에서 다음 배포 스크립트를 실행합니다.

```bash
./final_deploy.sh
```

성공적으로 배포되면, 새로운 컨트랙트 주소들이 터미널에 출력됩니다. 이 주소들을 `.env` 파일에 업데이트해야 합니다.

##  CLI 관리 도구

프로젝트 루트에는 컨트랙트를 쉽게 관리할 수 있는 셸 스크립트 세트가 포함되어 있습니다. 모든 스크립트는 루트의 `.env` 파일을 참조합니다.

### 통합 관리자 (추천)

모든 관리 기능을 메뉴 방식으로 제공하는 통합 스크립트입니다.

```bash
./token_manager.sh
```

### 개별 스크립트

| 스크립트 이름               | 설명                                                              |
| :-------------------------- | :---------------------------------------------------------------- |
| `./create_token.sh`         | 새로운 Security Token (과 배당 컨트랙트)을 생성합니다.            |
| `./list_tokens.sh`          | 현재까지 생성된 모든 토큰의 목록과 요약 정보를 보여줍니다.        |
| `./token_info.sh <주소>`    | 특정 토큰의 이름, 심볼, 총 발행량, 소유자 등 상세 정보를 봅니다. |
| `./transfer_token.sh`       | Admin 계정에서 다른 주소로 특정 토큰을 전송합니다.                |
| `./manage_whitelist.sh`     | 특정 토큰의 화이트리스트에 새로운 주소를 추가합니다.              |
| `./distribute_dividend.sh`  | 특정 토큰 보유자들에게 KRWT로 배당을 분배합니다. (2단계 실행)     |

## 🔗 백엔드 연동

백엔드 애플리케이션과의 연동을 위한 상세 가이드는 `BACKEND_INTEGRATION.md` 파일을 참조하세요. 이 파일에는 Web3j 설정, 개인키 관리, 이벤트 구독 및 함수 호출 방법 등이 포함됩니다.