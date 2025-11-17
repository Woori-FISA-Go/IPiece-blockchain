// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SecurityToken} from "../src/SecurityToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SecurityTokenTest is Test {
    SecurityToken token;
    address owner = address(1);
    address investor = address(2);
    address other = address(3);
    
    function setUp() public {
        vm.startPrank(owner);
        token = new SecurityToken("RunningMan-IP", "RMI", 1000000, owner);
        vm.stopPrank();
    }
    
    function test_InitialSupplyAndOwnerWhitelist() public view {
        assertEq(token.totalSupply(), 1000000 * 10 ** 18, "Initial supply mismatch");
        assertTrue(token.whitelist(owner), "Deployer not whitelisted");
        assertEq(token.balanceOf(owner), 1000000 * 10 ** 18, "Deployer balance mismatch");
    }
    
    function test_AddToWhitelist() public {
        vm.startPrank(owner);
        token.addToWhitelist(investor);
        vm.stopPrank();
        assertTrue(token.whitelist(investor), "Investor not added to whitelist");
    }

    function test_RevertWhen_AddToWhitelist_NotOwner() public {
        vm.startPrank(investor);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, investor));
        token.addToWhitelist(other);
        vm.stopPrank();
    }

    function test_Transfer_Whitelisted() public {
        vm.startPrank(owner);
        token.addToWhitelist(investor);
        require(token.transfer(investor, 100 * 10 ** 18), "Token transfer failed");
        vm.stopPrank();

        assertEq(token.balanceOf(owner), 999900 * 10 ** 18, "Seller balance mismatch");
        assertEq(token.balanceOf(investor), 100 * 10 ** 18, "Buyer balance mismatch");
    }

    function test_RevertWhen_Transfer_SenderNotWhitelisted() public {
        // owner는 화이트리스트에 있지만, investor가 아닌 other가 전송 시도
        vm.startPrank(other);
        vm.expectRevert("Not whitelisted");
        bool success = token.transfer(investor, 10 * 10 ** 18);
        vm.stopPrank();
    }

    function test_RevertWhen_Transfer_RecipientNotWhitelisted() public {
        vm.startPrank(owner);
        // investor는 화이트리스트에 있지만, other는 아님
        token.addToWhitelist(investor);
        vm.expectRevert("Recipient not whitelisted");
        bool success = token.transfer(other, 10 * 10 ** 18);
        vm.stopPrank();
    }
}