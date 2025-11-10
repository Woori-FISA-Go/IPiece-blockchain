// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SecurityToken.sol";
import "./KRWT.sol";

contract DividendDistributor is Ownable {
    SecurityToken public securityToken;
    KRWT public krwt;
    
    struct Dividend {
        uint256 totalAmount;
        uint256 distributedCount;
        uint256 declaredAt;
    }
    
    Dividend[] public dividends;
    
    event DividendDeclared(uint256 indexed dividendId, uint256 amount);
    event DividendDistributed(
        uint256 indexed dividendId,
        address indexed investor,
        uint256 amount
    );
    
    constructor(address _securityToken, address _krwt) Ownable(msg.sender) {
        securityToken = SecurityToken(_securityToken);
        krwt = KRWT(_krwt);
    }
    
    /**
     * 배당 실행 (Push 방식 - 자동!)
     */
    function distributeDividend(address[] calldata investors) external onlyOwner {
        require(investors.length > 0, "No investors");
        
        uint256 totalSupply = securityToken.totalSupply();
        uint256 totalAmount = krwt.balanceOf(address(this));
        require(totalAmount > 0, "No dividend balance");
        
        // 배당 기록
        uint256 dividendId = dividends.length;
        dividends.push(Dividend({
            totalAmount: totalAmount,
            distributedCount: 0,
            declaredAt: block.timestamp
        }));
        
        emit DividendDeclared(dividendId, totalAmount);
        
        // 자동 배당 (한 번에!)
        for (uint i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 balance = securityToken.balanceOf(investor);
            
            if (balance > 0) {
                uint256 share = (totalAmount * balance) / totalSupply;
                
                require(
                    krwt.transfer(investor, share),
                    "Transfer failed"
                );
                
                dividends[dividendId].distributedCount++;
                
                emit DividendDistributed(dividendId, investor, share);
            }
        }
    }
    
    /**
     * 배당 조회
     */
    function getDividendCount() external view returns (uint256) {
        return dividends.length;
    }
}