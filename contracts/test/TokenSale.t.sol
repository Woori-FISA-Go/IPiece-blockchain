// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TokenSale} from "../src/TokenSale.sol";
import {SecurityToken} from "../src/SecurityToken.sol";
import {KRWT} from "../src/KRWT.sol";

contract TokenSaleTest is Test {
    TokenSale public sale;
    SecurityToken public securityToken;
    KRWT public krwt;

    address public deployer;
    address public investor1;
    address public investor2;

    uint256 public price = 1000 * 10**18; // 1 token = 1000 KRWT
    uint256 public softCap = 50000 * 10**18;
    uint256 public hardCap = 100000 * 10**18;
    uint256 public saleStartTime;
    uint256 public saleEndTime;

    function setUp() public {
        deployer = makeAddr("deployer");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");

        vm.startPrank(deployer);
        // Deploy tokens
        securityToken = new SecurityToken("Sale Token", 100000); // 100,000 tokens total supply
        krwt = new KRWT();

        // Setup sale times
        saleStartTime = block.timestamp + 1 days;
        saleEndTime = saleStartTime + 7 days;

        // Deploy TokenSale contract
        sale = new TokenSale(
            address(securityToken),
            address(krwt),
            price,
            softCap,
            hardCap,
            saleStartTime,
            saleEndTime
        );

        // Add the sale contract to the whitelist so it can receive SecurityTokens
        securityToken.addToWhitelist(address(sale));

        // Fund investors with KRWT
        krwt.mint(investor1, 100000 * 10**18);
        krwt.mint(investor2, 100000 * 10**18);

        // Transfer SecurityTokens to the sale contract
        uint256 tokensForSale = (hardCap * (10**18)) / price;
        require(securityToken.transfer(address(sale), tokensForSale), "Token transfer failed");
        vm.stopPrank();

        // Whitelist investors
        vm.startPrank(deployer);
        securityToken.addToWhitelist(investor1);
        securityToken.addToWhitelist(investor2);
        vm.stopPrank();
    }

    function test_BuyTokens_Success() public {
        vm.warp(saleStartTime + 1 hours); // Move time to during the sale

        uint256 purchaseAmount = 20000 * 10**18; // 20,000 KRWT

        vm.startPrank(investor1);
        krwt.approve(address(sale), purchaseAmount);
        sale.buyTokens(purchaseAmount);
        vm.stopPrank();

        assertEq(sale.contributions(investor1), purchaseAmount);
        assertEq(sale.totalKrwtRaised(), purchaseAmount);
        assertEq(krwt.balanceOf(address(sale)), purchaseAmount);
    }

    function test_Finalize_Success() public {
        vm.warp(saleStartTime + 1 hours);

        // Investor 1 buys
        uint256 purchase1 = 60000 * 10**18;
        vm.startPrank(investor1);
        krwt.approve(address(sale), purchase1);
        sale.buyTokens(purchase1);
        vm.stopPrank();

        // Investor 2 buys
        uint256 purchase2 = 40000 * 10**18;
        vm.startPrank(investor2);
        krwt.approve(address(sale), purchase2);
        sale.buyTokens(purchase2);
        vm.stopPrank();

        // Finalize sale
        vm.warp(saleEndTime + 1 hours);
        vm.startPrank(deployer);
        sale.finalizeSale();
        vm.stopPrank();

        // Check balances
        uint256 tokens1 = (purchase1 * 10**18) / price;
        uint256 tokens2 = (purchase2 * 10**18) / price;
        assertEq(securityToken.balanceOf(investor1), tokens1);
        assertEq(securityToken.balanceOf(investor2), tokens2);
        assertEq(krwt.balanceOf(deployer), hardCap);
        assertEq(krwt.balanceOf(address(sale)), 0);
    }

    function test_Finalize_Fail_And_Refund() public {
        vm.warp(saleStartTime + 1 hours);

        // Investor 1 buys, but not enough to meet softcap
        uint256 purchase1 = 30000 * 10**18;
        vm.startPrank(investor1);
        krwt.approve(address(sale), purchase1);
        sale.buyTokens(purchase1);
        vm.stopPrank();

        uint256 initialKrwtBalance = krwt.balanceOf(investor1);

        // Finalize sale
        vm.warp(saleEndTime + 1 hours);
        vm.startPrank(deployer);
        sale.finalizeSale();
        vm.stopPrank();

        // Check balances
        assertEq(securityToken.balanceOf(investor1), 0); // No tokens received
        assertEq(krwt.balanceOf(investor1), initialKrwtBalance + purchase1); // Refunded
        assertEq(krwt.balanceOf(address(sale)), 0);
    }
}
