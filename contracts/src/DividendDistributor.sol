// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DividendDistributor
 * @notice Push 방식 배당 시스템 (Decimals 0 최적화)
 */
contract DividendDistributor is Ownable {
    IERC20 public immutable securityToken;
    IERC20 public immutable krwtToken;
    
    // 정책
    uint256 public constant MIN_TOTAL_DIVIDEND = 1000; // 최소 총 배당액
    uint256 public constant MIN_PER_SHARE = 1; // 1주당 최소 배당액
    
    // 통계
    uint256 public totalDividendsDistributed;
    uint256 public totalDistributionCount;
    
    event DividendDistributed(
        uint256 indexed distributionId,
        uint256 totalAmount,
        uint256 distributed,
        uint256 remainder,
        uint256 recipientCount
    );
    
    event DividendPaid(
        uint256 indexed distributionId,
        address indexed recipient,
        uint256 amount
    );
    
    event RemainderReturned(address indexed owner, uint256 amount);
    
    constructor(address _securityToken, address _krwtToken, address initialOwner) 
        Ownable(initialOwner)
    {
        require(_securityToken != address(0), "Invalid token");
        require(_krwtToken != address(0), "Invalid KRWT");
        
        securityToken = IERC20(_securityToken);
        krwtToken = IERC20(_krwtToken);
    }
    
    /**
     * @notice 배당 실행 (Push 방식)
     * @param totalAmount 총 배당액
     * @param recipients 배당 받을 주소 목록
     */
    function distributeDividend(
        uint256 totalAmount,
        address[] calldata recipients
    ) external onlyOwner returns (uint256 distributed, uint256 remainder) {
        // 1. 기본 검증
        require(totalAmount >= MIN_TOTAL_DIVIDEND, "Dividend too small");
        require(recipients.length > 0, "No recipients");
        
        uint256 totalSupply = securityToken.totalSupply();
        require(totalSupply > 0, "No tokens issued");
        
        // 2. 1주당 배당액 확인
        uint256 perShare = totalAmount / totalSupply;
        require(perShare >= MIN_PER_SHARE, "Per-share dividend too small");
        
        // 3. KRWT 입금 (Admin이 컨트랙트에 Approve 해둔 금액을 가져옴)
        krwtToken.transferFrom(msg.sender, address(this), totalAmount);
        
        // 4. 각 투자자에게 배당
        uint256 distributionId = totalDistributionCount;
        distributed = 0;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 shares = securityToken.balanceOf(recipient);
            
            if (shares == 0) continue;
            
            // 정수 나눗셈으로 배당액 계산
            uint256 amount = (totalAmount * shares) / totalSupply;
            
            if (amount > 0) {
                krwtToken.transfer(recipient, amount);
                distributed += amount;
                
                emit DividendPaid(distributionId, recipient, amount);
            }
        }
        
        // 5. 나머지 처리
        remainder = totalAmount - distributed;
        
        if (remainder > 0) {
            // 나머지를 Owner에게 반환
            krwtToken.transfer(owner(), remainder);
            emit RemainderReturned(owner(), remainder);
        }
        
        // 6. 통계 업데이트
        totalDividendsDistributed += distributed;
        totalDistributionCount++;
        
        emit DividendDistributed(
            distributionId,
            totalAmount,
            distributed,
            remainder,
            recipients.length
        );
        
        return (distributed, remainder);
    }
    
    /**
     * @notice 배당 시뮬레이션 (실행 전 미리보기)
     */
    function simulateDividend(
        uint256 totalAmount,
        address[] calldata recipients
    ) external view returns (
        bool canDistribute,
        string memory reason,
        uint256 totalDistributed,
        uint256 totalRemainder,
        uint256[] memory amounts
    ) {
        // 검증
        if (totalAmount < MIN_TOTAL_DIVIDEND) {
            return (false, "Dividend too small", 0, 0, new uint256[](0));
        }
        
        if (recipients.length == 0) {
            return (false, "No recipients", 0, 0, new uint256[](0));
        }
        
        uint256 totalSupply = securityToken.totalSupply();
        if (totalSupply == 0) {
            return (false, "No tokens issued", 0, 0, new uint256[](0));
        }
        
        uint256 perShare = totalAmount / totalSupply;
        if (perShare < MIN_PER_SHARE) {
            return (false, "Per-share dividend too small", 0, 0, new uint256[](0));
        }
        
        // 시뮬레이션
        amounts = new uint256[](recipients.length);
        totalDistributed = 0;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 shares = securityToken.balanceOf(recipients[i]);
            uint256 amount = (totalAmount * shares) / totalSupply;
            
            amounts[i] = amount;
            totalDistributed += amount;
        }
        
        totalRemainder = totalAmount - totalDistributed;
        
        return (true, "OK", totalDistributed, totalRemainder, amounts);
    }
    
    /**
     * @notice 긴급 출금 (Owner만)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = krwtToken.balanceOf(address(this));
        if (balance > 0) {
            krwtToken.transfer(owner(), balance);
        }
    }
}
