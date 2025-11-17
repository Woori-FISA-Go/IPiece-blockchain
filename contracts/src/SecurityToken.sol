// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SecurityToken is ERC20, Ownable {
    string public characterName;
    mapping(address => bool) public whitelist;
    
    constructor(string memory _name, uint256 _supply) ERC20(_name, "IPT") Ownable(msg.sender) {
        characterName = _name;
        _mint(msg.sender, _supply * 10 ** 18);
        whitelist[msg.sender] = true;
    }
    
    function addToWhitelist(address investor) external onlyOwner {
        whitelist[investor] = true;
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(whitelist[msg.sender], "Not whitelisted");
        require(whitelist[to], "Recipient not whitelisted");
        return super.transfer(to, amount);
    }
}