// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {SecurityToken} from "../src/SecurityToken.sol";
import {KRWT} from "../src/KRWT.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFactoryTest is Test {
    TokenFactory public factory;
    KRWT public krwt;

    address public deployer;
    address public user;

    uint256 public constant TEST_KRWT_CAP = 1_000_000_000_000_000_000_000_000_000_000_000; // 10^33

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");

        vm.startPrank(deployer);
        krwt = new KRWT(TEST_KRWT_CAP);
        factory = new TokenFactory(address(krwt));
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(factory.krwtAddress(), address(krwt));
        assertEq(factory.owner(), deployer);
    }

    function test_CreateToken_Success() public {
        vm.startPrank(deployer);
        
        // Emit check now includes the symbol
        vm.expectEmit(true, true, false, false);
        emit TokenFactory.TokenCreated(
            "New Awesome IP",
            "NAI",
            address(0), // This value is now ignored
            address(0), // This value is now ignored
            0           // This value is now ignored
        );

        (address newSecurityTokenAddr, address newDistributorAddr) = factory.createToken(
            "New Awesome IP",
            "NAI",
            1000, // Decimals are 0, so no need for * 10**18
            deployer
        );
        vm.stopPrank();

        // Check that the addresses are not zero
        assertNotEq(newSecurityTokenAddr, address(0));
        assertNotEq(newDistributorAddr, address(0));

        // Check ownership of new contracts
        SecurityToken newSecurityToken = SecurityToken(newSecurityTokenAddr);
        DividendDistributor newDistributor = DividendDistributor(newDistributorAddr);
        assertEq(newSecurityToken.owner(), deployer);
        assertEq(newDistributor.owner(), address(factory));

        // Check the symbol of the new token
        assertEq(newSecurityToken.symbol(), "NAI");

        // Check if the distributor is linked to the correct tokens
        assertEq(address(newDistributor.securityToken()), newSecurityTokenAddr);
        assertEq(address(newDistributor.krwtToken()), address(krwt));

        // Check if the factory tracks the new token
        assertEq(factory.getTokenCount(), 1);
        (string memory name, string memory symbol, address tokenAddr, ,) = factory.tokens(0);
        assertEq(name, "New Awesome IP");
        assertEq(symbol, "NAI");
        assertEq(tokenAddr, newSecurityTokenAddr);
        assertTrue(factory.tokenExists("New Awesome IP"));
    }

    function test_CreateToken_Reverts_IfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        factory.createToken("Another IP", "AIP", 500, user);
        vm.stopPrank();
    }

    function test_CreateToken_Reverts_IfNameExists() public {
        vm.startPrank(deployer);
        factory.createToken("Existing IP", "EIP", 1000, deployer);
        
        vm.expectRevert("Token already exists");
        factory.createToken("Existing IP", "EIP2", 2000, deployer);
        vm.stopPrank();
    }
}
