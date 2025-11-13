// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {SecurityToken} from "../src/SecurityToken.sol";
import {KRWT} from "../src/KRWT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DividendDistributorTest is Test {
    DividendDistributor public distributor;
    SecurityToken public securityToken;
    KRWT public krwt;

    address public deployer;
    address public investor1;
    address public investor2;
    address public nonInvestor;

    function setUp() public {
        deployer = makeAddr("deployer");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        nonInvestor = makeAddr("nonInvestor");

        vm.startPrank(deployer);
        securityToken = new SecurityToken("TestIP", "TIP", 1000, deployer); // 1000 tokens
        krwt = new KRWT();
        distributor = new DividendDistributor(address(securityToken), address(krwt));
        vm.stopPrank();

        // Mint some KRWT to the deployer for testing
        vm.startPrank(deployer);
        krwt.mint(deployer, 10000 * 10 ** 18); // 10000 KRWT
        vm.stopPrank();

        // Whitelist investors for SecurityToken
        vm.startPrank(deployer);
        securityToken.addToWhitelist(investor1);
        securityToken.addToWhitelist(investor2);
        vm.stopPrank();

        // Distribute SecurityTokens to investors
        vm.startPrank(deployer);
        require(securityToken.transfer(investor1, 500 * 10 ** 18), "Token transfer failed"); // 500 tokens to investor1
        require(securityToken.transfer(investor2, 300 * 10 ** 18), "Token transfer failed"); // 300 tokens to investor2
        // deployer holds 200 tokens
        vm.stopPrank();
    }

    function testOnlyOwnerCanDistribute() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                investor1
            )
        );
        vm.startPrank(investor1);
        address[] memory investors = new address[](1);
        investors[0] = investor1;
        distributor.distributeDividend(investors);
        vm.stopPrank();
    }

    function testDistributeDividendSuccess() public {
        // Transfer KRWT to distributor contract
        vm.startPrank(deployer);
        require(krwt.transfer(address(distributor), 1000 * 10 ** 18), "KRWT transfer failed"); // 1000 KRWT for dividend
        vm.stopPrank();

        // Prepare investor list
        address[] memory investors = new address[](3);
        investors[0] = deployer;
        investors[1] = investor1;
        investors[2] = investor2;

        // Check initial KRWT balances
        assertEq(krwt.balanceOf(deployer), 9000 * 10 ** 18);
        assertEq(krwt.balanceOf(investor1), 0);
        assertEq(krwt.balanceOf(investor2), 0);
        assertEq(krwt.balanceOf(address(distributor)), 1000 * 10 ** 18);

        vm.startPrank(deployer);
        distributor.distributeDividend(investors);
        vm.stopPrank();

        // Check final KRWT balances
        // Total supply = 1000 tokens
        // Total dividend = 1000 KRWT
        // deployer (200 tokens) should get 200 KRWT
        // investor1 (500 tokens) should get 500 KRWT
        // investor2 (300 tokens) should get 300 KRWT
        assertEq(krwt.balanceOf(deployer), 9000 * 10 ** 18 + 200 * 10 ** 18);
        assertEq(krwt.balanceOf(investor1), 500 * 10 ** 18);
        assertEq(krwt.balanceOf(investor2), 300 * 10 ** 18);
        assertEq(krwt.balanceOf(address(distributor)), 0); // All distributed
    }

    function testDistributeDividendWithZeroBalanceInvestor() public {
        // Transfer KRWT to distributor contract
        vm.startPrank(deployer);
        require(krwt.transfer(address(distributor), 1000 * 10 ** 18), "KRWT transfer failed"); // 1000 KRWT for dividend
        vm.stopPrank();

        // Prepare investor list including nonInvestor (0 SecurityToken balance)
        address[] memory investors = new address[](4);
        investors[0] = deployer;
        investors[1] = investor1;
        investors[2] = investor2;
        investors[3] = nonInvestor; // This address has 0 SecurityToken

        // Check initial KRWT balances
        assertEq(krwt.balanceOf(deployer), 9000 * 10 ** 18);
        assertEq(krwt.balanceOf(investor1), 0);
        assertEq(krwt.balanceOf(investor2), 0);
        assertEq(krwt.balanceOf(nonInvestor), 0);
        assertEq(krwt.balanceOf(address(distributor)), 1000 * 10 ** 18);

        vm.startPrank(deployer);
        distributor.distributeDividend(investors);
        vm.stopPrank();

        // Check final KRWT balances
        assertEq(krwt.balanceOf(deployer), 9000 * 10 ** 18 + 200 * 10 ** 18);
        assertEq(krwt.balanceOf(investor1), 500 * 10 ** 18);
        assertEq(krwt.balanceOf(investor2), 300 * 10 ** 18);
        assertEq(krwt.balanceOf(nonInvestor), 0); // Should still be 0
        assertEq(krwt.balanceOf(address(distributor)), 0); // All distributed
    }

    function testDistributeDividendNoBalanceInDistributor() public {
        vm.expectRevert("No dividend balance");
        vm.startPrank(deployer);
        address[] memory investors = new address[](1);
        investors[0] = deployer;
        distributor.distributeDividend(investors);
        vm.stopPrank();
    }

    function testDistributeDividendNoInvestors() public {
        vm.expectRevert("No investors");
        vm.startPrank(deployer);
        address[] memory investors = new address[](0);
        distributor.distributeDividend(investors);
        vm.stopPrank();
    }
}
