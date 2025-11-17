# IPiece 블록체인 컨트랙트 백엔드 연동 가이드

이 문서는 IPiece 플랫폼의 Spring Boot 백엔드 애플리케이션이 Hyperledger Besu 블록체인 네트워크에 배포된 스마트 컨트랙트들과 효과적으로 상호작용하기 위한 가이드라인을 제공합니다.

---

## 1. 네트워크 연결 설정

Spring Boot 애플리케이션은 Hyperledger Besu 노드의 JSON-RPC 엔드포인트를 통해 블록체인과 통신합니다.

*   **연결 방식:** HTTP/HTTPS 기반 JSON-RPC
*   **라이브러리:** Java Web3j (Gradle 의존성 추가 필요)
*   **Besu 노드 주소:** `http://<Besu 노드 내부 IP 주소>:8545` (예: `http://192.168.1.100:8545`)
    *   **주의:** AWS와 온프레미스 Besu 노드 간의 VPN 및 방화벽(pfSense) 설정이 올바르게 되어 있어야 합니다.

### Web3j 의존성 (build.gradle)

```gradle
dependencies {
    implementation 'org.web3j:core:4.9.8' // 최신 버전 확인 필요
    // 기타 필요한 의존성
}
```

### Web3j 초기화 (Spring Boot Configuration)

```java
@Configuration
public class Web3jConfig {

    @Value("${web3j.client.url}")
    private String web3jClientUrl;

    @Bean
    public Web3j web3j() {
        return Web3j.build(new HttpService(web3jClientUrl));
    }
}
```

`application.yml` 또는 `application.properties`에 Besu 노드 URL 설정:

```yaml
web3j:
  client:
    url: http://192.168.1.100:8545 # 실제 Besu 노드 IP 주소로 변경
```

---

## 2. 관리자 개인키 관리 (매우 중요!)

컨트랙트의 `onlyOwner` 함수를 호출하거나, `SecurityToken`을 `TokenSale` 컨트랙트로 전송하는 등의 관리자 액션에는 관리자 계정의 개인키가 필요합니다.

*   **절대 금지:** 개인키를 소스코드, 설정 파일, 환경 변수에 직접 저장하는 것은 **절대 금지**입니다.
*   **권장 방식:** **AWS Secrets Manager** 또는 **AWS Parameter Store**와 같은 클라우드 네이티브 보안 서비스를 사용하여 개인키를 안전하게 저장하고, 애플리케이션 실행 시 동적으로 읽어와 사용해야 합니다.

### 예시 (AWS Secrets Manager 사용)

```java
// Secrets Manager에서 개인키를 읽어오는 서비스 (예시)
public class AdminKeyService {
    public Credentials getAdminCredentials() {
        // AWS Secrets Manager 또는 Parameter Store에서 개인키를 안전하게 로드
        String privateKey = getPrivateKeyFromSecretsManager("admin-private-key-secret-name");
        return Credentials.create(privateKey);
    }

    private String getPrivateKeyFromSecretsManager(String secretName) {
        // AWS SDK를 사용하여 Secrets Manager에서 시크릿 값을 가져오는 로직 구현
        // ...
        return "0x..."; // 로드된 개인키 반환
    }
}
```

---

## 3. 컨트랙트 배포 순서

컨트랙트들은 특정 의존성을 가지므로, 다음 순서로 배포되어야 합니다.

1.  **`KRWT.sol`:** 플랫폼의 기축 통화.
2.  **`TokenFactory.sol`:** `KRWT` 컨트랙트 주소와 최종 관리자(`admin`) 주소를 인자로 받아 배포.
3.  **`SecurityToken.sol` / `DividendDistributor.sol`:** `TokenFactory`의 `createTokenSet` 함수를 통해 생성.
4.  **`TokenSale.sol`:** 판매할 `SecurityToken` 주소, `KRWT` 주소, 공모 파라미터들을 인자로 받아 배포.

---

## 4. 백엔드가 구독해야 할 주요 이벤트

백엔드는 컨트랙트에서 발생하는 이벤트를 구독하여 오프체인 데이터베이스를 업데이트하고 사용자에게 알림을 제공합니다.

*   **`TokenFactory.sol`:**
    *   `TokenSetCreated(address indexed securityToken, address indexed dividendDistributor, string name, uint256 initialSupply)`
        *   **용도:** 새로운 IP 상품(SecurityToken + DividendDistributor 세트)이 생성되었을 때 감지하여 백엔드 DB에 상품 정보 등록.
*   **`TokenSale.sol`:**
    *   `TokensPurchased(address indexed buyer, uint256 krwtAmount, uint256 tokenAmount)`
        *   **용도:** 투자자가 토큰을 구매했을 때 감지하여 사용자 구매 내역 및 총 모금액 업데이트.
    *   `SaleFinalized(uint256 totalRaised)`
        *   **용도:** 공모가 최종 확정되었을 때 감지하여 공모 상태(성공/실패) 업데이트 및 관련 후처리 로직 실행.
    *   `RefundsProcessed()`
        *   **용도:** 공모 실패 시 환불이 완료되었음을 감지 (선택 사항, `SaleFinalized`로도 충분할 수 있음).
*   **`DividendDistributor.sol`:**
    *   `DividendDeclared(uint256 indexed dividendId, uint256 amount)`
        *   **용도:** 새로운 배당이 시작되었을 때 감지하여 사용자에게 배당 알림 제공.
    *   `DividendDistributed(address indexed investor, uint256 amount)`
        *   **용도:** 각 투자자에게 배당금이 지급되었을 때 감지하여 사용자 잔고 업데이트 및 알림 제공.

### Web3j 이벤트 구독 예시

```java
// TokenFactory의 TokenSetCreated 이벤트 구독 예시
public void subscribeToTokenSetCreatedEvents(Web3j web3j, String tokenFactoryAddress) {
    TokenFactory tokenFactory = TokenFactory.load(tokenFactoryAddress, web3j, null, null); // Credentials, GasProvider는 필요에 따라 설정

    tokenFactory.tokenSetCreatedEventFlowable(DefaultBlockParameterName.LATEST, DefaultBlockParameterName.LATEST)
        .subscribe(event -> {
            log.info("새로운 토큰 세트 생성 감지: SecurityToken={}, Distributor={}, Name={}, Supply={}",
                event.securityToken, event.dividendDistributor, event.name, event.initialSupply);
            // DB 업데이트, 알림 발송 등 백엔드 로직 구현
        }, Throwable::printStackTrace);
}
```

---

## 5. 백엔드가 호출해야 할 주요 함수

백엔드는 관리자 액션 또는 자동화된 프로세스를 통해 컨트랙트의 특정 함수를 호출합니다.

*   **`KRWT.sol`:**
    *   `mint(address to, uint256 amount)`: 관리자가 사용자에게 KRWT를 지급하거나, 초기 KRWT를 발행할 때 사용.
    *   `burn(address from, uint256 amount)`: 관리자가 KRWT를 회수하거나 소각할 때 사용.
*   **`SecurityToken.sol`:**
    *   `addToWhitelist(address investor)`: 관리자가 투자자를 화이트리스트에 추가할 때 사용.
    *   `transfer(address to, uint256 amount)`: 관리자가 `TokenSale` 컨트랙트에 판매할 `SecurityToken`을 전송할 때 사용.
*   **`TokenFactory.sol`:**
    *   `createTokenSet(string memory _name, uint256 _initialSupply)`: 관리자가 새로운 IP 상품을 생성할 때 사용.
    *   `setAdmin(address _newAdmin)`: 팩토리의 관리자 주소를 변경할 때 사용.
*   **`TokenSale.sol`:**
    *   `buyTokens(uint256 krwtAmount)`: 투자자가 토큰을 구매할 때 사용 (백엔드가 사용자 대신 호출하거나, 사용자 지갑을 통해 직접 호출).
    *   `finalizeSale()`: 관리자가 공모 기간 종료 후 공모를 최종 확정할 때 사용.
*   **`DividendDistributor.sol`:**
    *   `distributeDividend(address[] calldata investors)`: 관리자가 배당금 분배를 시작할 때 사용. (이 함수 호출 전에 `DividendDistributor` 컨트랙트에 `KRWT`를 전송해야 함)

### Web3j 함수 호출 예시

```java
// TokenFactory의 createTokenSet 함수 호출 예시
public TransactionReceipt createNewTokenSet(
    Web3j web3j,
    Credentials credentials, // 관리자 개인키로 생성된 Credentials
    String tokenFactoryAddress,
    String name,
    BigInteger initialSupply
) throws Exception {
    TokenFactory tokenFactory = TokenFactory.load(
        tokenFactoryAddress, web3j, credentials, new DefaultGasProvider());

    return tokenFactory.createTokenSet(name, initialSupply).send();
}
```

---

## 6. 추가 고려사항

*   **가스비:** Hyperledger Besu는 프라이빗 체인이므로 트랜잭션 가스비가 0으로 설정될 수 있습니다. 하지만 `DefaultGasProvider`를 사용하는 경우, 적절한 `GasPrice`와 `GasLimit`을 설정해야 합니다.
*   **트랜잭션 모니터링:** 백엔드는 전송한 트랜잭션의 상태(Pending, Success, Fail)를 지속적으로 모니터링하고, 실패 시 재시도 로직을 구현해야 합니다.
*   **데이터 동기화:** 블록체인 이벤트와 백엔드 DB 간의 데이터 일관성을 유지하기 위한 강력한 동기화 전략이 필요합니다.

---
