// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SecurityToken} from "./SecurityToken.sol";
import {KRWT} from "./KRWT.sol";

/**
 * @title 배당금 분배 컨트랙트
 * @author IPiece 프로젝트
 * @notice 특정 SecurityToken 보유자들에게 KRWT로 배당금을 분배하는 역할을 관리합니다.
 * @dev Push 기반 모델을 사용하여 배당금을 분배합니다. 소유자가 프로세스를 시작하면,
 * 컨트랙트가 루프를 통해 모든 토큰 보유자에게 자동으로 KRWT를 전송합니다.
 * 이 방식은 관리 가능한 수의 보유자를 가진 프라이빗 체인에 적합합니다.
 */
contract DividendDistributor is Ownable {
    /// @notice 배당금이 분배될 대상 SecurityToken 컨트랙트입니다.
    SecurityToken public securityToken;
    /// @notice 배당금 지급 통화로 사용되는 KRWT 토큰 컨트랙트입니다.
    KRWT public krwt;
    
    /// @notice 단일 배당금 분배 이벤트에 대한 기록입니다.
    struct Dividend {
        uint256 totalAmount;
        uint256 distributedCount;
        uint256 declaredAt;
    }
    
    /// @notice 모든 배당금 분배 내역을 저장하는 배열입니다.
    Dividend[] public dividends;
    
    /// @notice 소유자에 의해 새로운 배당금 분배가 시작될 때 발생합니다.
    event DividendDeclared(uint256 indexed dividendId, uint256 amount);
    /// @notice 배당금을 지급받는 각 투자자에 대해 발생합니다.
    event DividendDistributed(
        uint256 indexed dividendId,
        address indexed investor,
        uint256 amount
    );
    
    /**
     * @notice 분배 컨트랙트를 특정 SecurityToken 및 KRWT 컨트랙트에 연결합니다.
     * @param _securityToken 배당금을 받을 토큰 보유자들의 SecurityToken 컨트랙트 주소.
     * @param _krwt KRWT 토큰 컨트랙트의 주소.
     */
    constructor(address _securityToken, address _krwt) Ownable(msg.sender) {
        securityToken = SecurityToken(_securityToken);
        krwt = KRWT(_krwt);
    }
    
    /**
     * @notice 배당금 분배를 시작합니다.
     * @dev 이 함수는 제공된 투자자 목록을 반복하며, 실행 시점의 토큰 잔액을 기준으로
     * 그들에게 KRWT 배당금을 푸시합니다. 총 배당액은 이 컨트랙트의 전체 KRWT 잔액입니다.
     * 소유자만 호출할 수 있습니다.
     * @param investors 모든 현재 SecurityToken 보유자들의 주소 배열.
     */
    function distributeDividend(address[] calldata investors) external onlyOwner {
        require(investors.length > 0, "No investors");
        
        uint256 totalSupply = securityToken.totalSupply();
        uint256 totalAmount = krwt.balanceOf(address(this));
        require(totalAmount > 0, "No dividend balance");
        
        // 새로운 배당 기록 생성
        uint256 dividendId = dividends.length;
        dividends.push(Dividend({
            totalAmount: totalAmount,
            distributedCount: 0,
            declaredAt: block.timestamp
        }));
        
        emit DividendDeclared(dividendId, totalAmount);
        
        // 투자자들에게 루프를 돌며 지급
        for (uint i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 balance = securityToken.balanceOf(investor);
            
            if (balance > 0) {
                uint256 share = (totalAmount * balance) / totalSupply;
                
                require(krwt.transfer(investor, share), "KRWT transfer failed");
                
                dividends[dividendId].distributedCount++;
                
                emit DividendDistributed(dividendId, investor, share);
            }
        }
    }
    
    /**
     * @notice 현재까지 발생한 총 배당 횟수를 반환합니다.
     * @return 과거 배당 분배 횟수.
     */
    function getDividendCount() external view returns (uint256) {
        return dividends.length;
    }
}