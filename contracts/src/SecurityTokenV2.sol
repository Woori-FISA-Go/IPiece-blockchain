// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IP 권리를 위한 증권형 토큰 V2 (forceTransfer 포함)
 */
contract SecurityTokenV2 is ERC20, Ownable {
    mapping(address => bool) public whitelist;

    event AddedToWhitelist(address indexed account);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address initialOwner
    )
        ERC20(_name, _symbol)
        Ownable(initialOwner)
    {
        _mint(initialOwner, _supply);
        whitelist[initialOwner] = true;
        emit AddedToWhitelist(initialOwner);
    }

    function decimals() public view virtual override returns (uint8) {
        // 기존처럼 소수점 0자리
        return 0;
    }

    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
        emit AddedToWhitelist(account);
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(whitelist[msg.sender], "Not whitelisted");
        require(whitelist[to], "Recipient not whitelisted");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(whitelist[from], "Not whitelisted");
        require(whitelist[to], "Recipient not whitelisted");
        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice 관리자(owner)가 강제로 토큰을 이동시키는 함수
     */
    function forceTransfer(address from, address to, uint256 amount)
        external
        onlyOwner
    {
        require(whitelist[from], "Not whitelisted");
        require(whitelist[to], "Recipient not whitelisted");
        // OZ 5.x ERC20 내부 이동 로직
        _update(from, to, amount);
    }
}
