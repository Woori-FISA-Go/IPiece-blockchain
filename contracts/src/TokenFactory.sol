// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SecurityToken} from "./SecurityToken.sol";
import {DividendDistributor} from "./DividendDistributor.sol";

contract TokenFactory is Ownable {
    address public immutable krwtToken;
    address public admin;

    address[] public allSecurityTokens;

    event TokenSetCreated(
        address indexed securityToken,
        address indexed dividendDistributor,
        string name,
        uint256 initialSupply
    );

    constructor(address _krwtToken, address _admin) Ownable(msg.sender) {
        require(_krwtToken != address(0), "KRWT address cannot be zero");
        require(_admin != address(0), "Admin address cannot be zero");
        krwtToken = _krwtToken;
        admin = _admin;
    }

    function createTokenSet(
        string memory _name,
        uint256 _initialSupply
    ) external onlyOwner returns (address, address) {
        // 1. Deploy a new SecurityToken
        SecurityToken newSecurityToken = new SecurityToken(_name, _initialSupply);

        // 2. Deploy a new DividendDistributor and link it
        DividendDistributor newDistributor = new DividendDistributor(
            address(newSecurityToken),
            krwtToken
        );

        // 3. Transfer ownership of the new contracts to the designated admin
        newSecurityToken.transferOwnership(admin);
        newDistributor.transferOwnership(admin);

        // 4. Store the new SecurityToken address
        allSecurityTokens.push(address(newSecurityToken));

        // 5. Emit an event for backend synchronization
        emit TokenSetCreated(
            address(newSecurityToken),
            address(newDistributor),
            _name,
            _initialSupply
        );

        return (address(newSecurityToken), address(newDistributor));
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "New admin address cannot be zero");
        admin = _newAdmin;
    }

    function getAllSecurityTokens() external view returns (address[] memory) {
        return allSecurityTokens;
    }
}
