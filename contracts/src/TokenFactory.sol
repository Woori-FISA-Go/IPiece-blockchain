// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SecurityToken} from "./SecurityToken.sol";
import {DividendDistributor} from "./DividendDistributor.sol";

contract TokenFactory is Ownable {
    address public krwtAddress;
    
    struct IPToken {
        string name;
        string symbol;
        address tokenAddress;
        address dividendAddress;
        uint256 createdAt;
    }
    
    IPToken[] public tokens;
    mapping(string => bool) public tokenExists;
    
    event TokenCreated(
        string indexed name,
        string symbol,
        address tokenAddress,
        address dividendAddress,
        uint256 totalSupply
    );
    
    constructor(address _krwtAddress) Ownable(msg.sender) {
        krwtAddress = _krwtAddress;
    }
    
    function createToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address initialOwner
    ) external onlyOwner returns (address, address) {
        require(!tokenExists[name], "Token already exists");
        
        SecurityToken newToken = new SecurityToken(name, symbol, totalSupply, initialOwner);
        DividendDistributor newDividend = new DividendDistributor(
            address(newToken),
            krwtAddress
        );
        
        tokens.push(IPToken({
            name: name,
            symbol: symbol,
            tokenAddress: address(newToken),
            dividendAddress: address(newDividend),
            createdAt: block.timestamp
        }));
        
        tokenExists[name] = true;
        
        emit TokenCreated(name, symbol, address(newToken), address(newDividend), totalSupply);
        
        return (address(newToken), address(newDividend));
    }
    
    function getTokenCount() external view returns (uint256) {
        return tokens.length;
    }

    // TokenFactory.sol에 화이트리스트 관리 함수 추가 (사용자 제안)
    function addToWhitelist(uint256 tokenIndex, address account) external onlyOwner {
        IPToken storage ipToken = tokens[tokenIndex];
        SecurityToken token = SecurityToken(ipToken.tokenAddress);
        token.addToWhitelist(account);
    }

    function transferTokens(
        uint256 tokenIndex, 
        address to, 
        uint256 amount
    ) external onlyOwner {
        IPToken storage ipToken = tokens[tokenIndex];
        SecurityToken token = SecurityToken(ipToken.tokenAddress);
        require(token.transfer(to, amount), "Token transfer failed");
    }
}
