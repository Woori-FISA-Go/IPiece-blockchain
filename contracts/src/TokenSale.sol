// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title 토큰 공모 컨트랙트 (Token Sale)
 * @author IPiece 프로젝트
 * @notice 신규 SecurityToken의 초기 공모(ICO)를 관리합니다. 공모 성공 시 토큰을 분배하고, 실패 시 KRWT를 환불합니다.
 * @dev Ownable 및 ReentrancyGuard를 상속받습니다. 투자자는 `buyTokens` 호출 전,
 * 이 컨트랙트 주소에 대해 KRWT 지출을 `approve` 해야 합니다.
 */
contract TokenSale is Ownable, ReentrancyGuard {
    /// @notice 판매 대상인 SecurityToken 컨트랙트의 인터페이스입니다.
    IERC20 public securityToken;
    /// @notice 결제 수단인 KRWT 컨트랙트의 인터페이스입니다.
    IERC20 public krwt;

    /// @notice SecurityToken 1개당 KRWT 가격입니다 (18자리 소수점 기준).
    uint256 public price;
    /// @notice 공모 성공을 위한 최소 모금액 (KRWT 기준) 입니다.
    uint256 public softCap;
    /// @notice 최대 모금 가능액 (KRWT 기준) 입니다.
    uint256 public hardCap;
    /// @notice 공모 시작 시간 (Unix 타임스탬프) 입니다.
    uint256 public startTime;
    /// @notice 공모 종료 시간 (Unix 타임스탬프) 입니다.
    uint256 public endTime;

    /// @notice 현재까지 모금된 총 KRWT 금액입니다.
    uint256 public totalKrwtRaised;
    /// @notice 각 투자자가 투자한 KRWT 금액을 기록하는 매핑입니다.
    mapping(address => uint256) public contributions;
    /// @notice 투자에 참여한 모든 기여자의 주소를 저장하는 배열입니다.
    address[] public contributors;

    /// @notice 공모가 최종 확정되었는지 여부를 나타냅니다.
    bool public isFinalized;

    /// @notice 투자자가 토큰을 구매했을 때 발생하는 이벤트입니다.
    event TokensPurchased(address indexed buyer, uint256 krwtAmount, uint256 tokenAmount);
    /// @notice 공모가 최종 확정되었을 때 발생하는 이벤트입니다.
    event SaleFinalized(uint256 totalRaised);
    /// @notice 공모 실패로 환불이 처리되었을 때 발생하는 이벤트입니다.
    event RefundsProcessed();

    /**
     * @notice 새로운 토큰 공모를 위한 파라미터들을 설정하여 컨트랙트를 초기화합니다.
     * @param _securityTokenAddress 판매할 SecurityToken의 주소.
     * @param _krwtAddress 결제 수단으로 사용될 KRWT의 주소.
     * @param _price SecurityToken 1개당 KRWT 가격 (18자리 소수점 포함).
     * @param _softCap 공모 성공을 위한 최소 모금액.
     * @param _hardCap 최대 모금 가능액.
     * @param _startTime 공모 시작 시간 (Unix 타임스탬프).
     * @param _endTime 공모 종료 시간 (Unix 타임스탬프).
     */
    constructor(
        address _securityTokenAddress,
        address _krwtAddress,
        uint256 _price,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) {
        require(_securityTokenAddress != address(0) && _krwtAddress != address(0), "Zero address");
        require(_price > 0, "Price must be > 0");
        require(_softCap > 0 && _hardCap >= _softCap, "Invalid caps");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Invalid times");

        securityToken = IERC20(_securityTokenAddress);
        krwt = IERC20(_krwtAddress);
        price = _price;
        softCap = _softCap;
        hardCap = _hardCap;
        startTime = _startTime;
        endTime = _endTime;
    }

    /**
     * @notice 투자자가 KRWT를 사용하여 SecurityToken을 구매합니다.
     * @dev 투자자는 이 함수를 호출하기 전에, 구매할 `krwtAmount` 만큼 이 컨트랙트 주소에 `approve`를 해야 합니다.
     * 재진입 공격 방지(`nonReentrant`)가 적용되어 있습니다.
     * @param krwtAmount 구매에 사용할 KRWT의 양.
     */
    function buyTokens(uint256 krwtAmount) external nonReentrant {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Sale not active");
        require(krwtAmount > 0, "Amount must be > 0");
        require(totalKrwtRaised + krwtAmount <= hardCap, "Hard cap exceeded");

        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        // 구매자의 지갑에서 이 컨트랙트로 KRWT를 가져옵니다.
        require(krwt.transferFrom(msg.sender, address(this), krwtAmount), "KRWT transfer failed");
        
        contributions[msg.sender] += krwtAmount;
        totalKrwtRaised += krwtAmount;

        uint256 tokenAmount = (krwtAmount * (10**18)) / price;
        emit TokensPurchased(msg.sender, krwtAmount, tokenAmount);
    }

    /**
     * @notice 공모 기간 종료 후, 공모를 최종 확정합니다.
     * @dev 소유자만 호출할 수 있습니다. `softCap` 달성 여부에 따라 토큰을 분배하거나 투자금을 환불합니다.
     * 재진입 공격 방지가 적용되어 있습니다.
     */
    function finalizeSale() external onlyOwner nonReentrant {
        require(block.timestamp > endTime, "Sale not ended");
        require(!isFinalized, "Sale already finalized");

        isFinalized = true;

        if (totalKrwtRaised >= softCap) {
            // 공모 성공: 토큰 분배
            for (uint256 i = 0; i < contributors.length; i++) {
                address contributor = contributors[i];
                uint256 krwtContributed = contributions[contributor];
                uint256 tokenAmount = (krwtContributed * (10**18)) / price;
                
                require(securityToken.transfer(contributor, tokenAmount), "Token transfer failed");
            }
            // 모금된 KRWT를 소유자에게 전송
            require(krwt.transfer(owner(), totalKrwtRaised), "KRWT transfer failed");
        } else {
            // 공모 실패: KRWT 환불 (Push 모델)
            for (uint256 i = 0; i < contributors.length; i++) {
                address contributor = contributors[i];
                uint256 krwtContributed = contributions[contributor];
                require(krwt.transfer(contributor, krwtContributed), "Refund failed");
            }
            emit RefundsProcessed();
        }
        emit SaleFinalized(totalKrwtRaised);
    }

    /**
     * @notice 이 컨트랙트가 현재 보유하고 있는 SecurityToken의 잔액을 조회합니다.
     * @return SecurityToken 잔액.
     */
    function getSecurityTokenBalance() external view returns (uint256) {
        return securityToken.balanceOf(address(this));
    }
}
