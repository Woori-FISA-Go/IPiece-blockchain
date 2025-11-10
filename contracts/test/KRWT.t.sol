// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KRWT} from "../src/KRWT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KRWTTest is Test {
    KRWT krwt;
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    
    function setUp() public {
        vm.startPrank(owner);
        krwt = new KRWT();
        vm.stopPrank();
    }
    
    function test_InitialState() public view {
        assertEq(krwt.name(), "Korean Won Token", "Token name mismatch");
        assertEq(krwt.symbol(), "KRWT", "Token symbol mismatch");
        assertEq(krwt.owner(), owner, "Owner mismatch");
        assertEq(krwt.totalSupply(), 0, "Initial total supply should be 0");
    }
    
    function test_Mint() public {
        vm.startPrank(owner);
        krwt.mint(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        assertEq(krwt.balanceOf(user1), 1000 * 10 ** 18, "User1 balance after mint mismatch");
        assertEq(krwt.totalSupply(), 1000 * 10 ** 18, "Total supply after mint mismatch");
    }

    function test_RevertWhen_Mint_NotOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        krwt.mint(user2, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_Burn() public {
        vm.startPrank(owner);
        krwt.mint(user1, 1000 * 10 ** 18);
        krwt.burn(user1, 300 * 10 ** 18);
        vm.stopPrank();

        assertEq(krwt.balanceOf(user1), 700 * 10 ** 18, "User1 balance after burn mismatch");
        assertEq(krwt.totalSupply(), 700 * 10 ** 18, "Total supply after burn mismatch");
    }

    function test_RevertWhen_Burn_NotOwner() public {
        vm.startPrank(owner);
        krwt.mint(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        krwt.burn(user1, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.startPrank(owner);
        krwt.mint(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user1);
        require(krwt.transfer(user2, 200 * 10 ** 18), "KRWT transfer failed");
        vm.stopPrank();

        assertEq(krwt.balanceOf(user1), 800 * 10 ** 18, "User1 balance after transfer mismatch");
        assertEq(krwt.balanceOf(user2), 200 * 10 ** 18, "User2 balance after transfer mismatch");
    }
}