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
    address public admin;
    address public user;

    function setUp() public {
        deployer = makeAddr("deployer");
        admin = makeAddr("admin");
        user = makeAddr("user");

        vm.startPrank(deployer);
        krwt = new KRWT();
        factory = new TokenFactory(address(krwt), admin);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(factory.KRWT_TOKEN(), address(krwt));
        assertEq(factory.admin(), admin);
        assertEq(factory.owner(), deployer);
    }

    function test_CreateTokenSet_Success() public {
        vm.startPrank(deployer);
        
        // Expect the event to be emitted
        vm.expectEmit(false, false, true, true);
        emit TokenFactory.TokenSetCreated(
            address(0), // We don't know the address beforehand, so we can't check it precisely here without more complex code
            address(0),
            "New Awesome IP",
            1000 * 10**18
        );

        (address newSecurityTokenAddr, address newDistributorAddr) = factory.createTokenSet(
            "New Awesome IP",
            1000 * 10**18
        );
        vm.stopPrank();

        // Check that the addresses are not zero
        assertNotEq(newSecurityTokenAddr, address(0));
        assertNotEq(newDistributorAddr, address(0));

        // Check ownership of new contracts
        SecurityToken newSecurityToken = SecurityToken(newSecurityTokenAddr);
        DividendDistributor newDistributor = DividendDistributor(newDistributorAddr);
        assertEq(newSecurityToken.owner(), admin);
        assertEq(newDistributor.owner(), admin);

        // Check if the distributor is linked to the correct tokens
        assertEq(address(newDistributor.securityToken()), newSecurityTokenAddr);
        assertEq(address(newDistributor.krwt()), address(krwt));

        // Check if the factory tracks the new token
        address[] memory allTokens = factory.getAllSecurityTokens();
        assertEq(allTokens.length, 1);
        assertEq(allTokens[0], newSecurityTokenAddr);
    }

    function test_CreateTokenSet_Reverts_IfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        factory.createTokenSet("Another IP", 500 * 10**18);
        vm.stopPrank();
    }

    function test_SetAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        
        vm.startPrank(deployer);
        factory.setAdmin(newAdmin);
        vm.stopPrank();

        assertEq(factory.admin(), newAdmin);
    }

    function test_SetAdmin_Reverts_IfNotOwner() public {
        address newAdmin = makeAddr("newAdmin");

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        factory.setAdmin(newAdmin);
        vm.stopPrank();
    }
}
