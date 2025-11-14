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

    uint256 public constant TEST_KRWT_CAP = 1_000_000_000_000_000_000_000_000_000_000_000; // 10^33 (Decimals 0)
    uint256 public constant INITIAL_KRWT_MINT = 100_000; // 10만 KRWT
    uint256 public constant SECURITY_TOKEN_SUPPLY = 1_000; // 1000 FTT

    function setUp() public {
        deployer = makeAddr("deployer");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        nonInvestor = makeAddr("nonInvestor");

        vm.startPrank(deployer);
        securityToken = new SecurityToken("FinalTest", "FTT", SECURITY_TOKEN_SUPPLY, deployer);
        krwt = new KRWT(TEST_KRWT_CAP);
        distributor = new DividendDistributor(address(securityToken), address(krwt), deployer);
        vm.stopPrank();

        // Deployer에게 KRWT 발행
        vm.startPrank(deployer);
        krwt.mint(deployer, INITIAL_KRWT_MINT);
        vm.stopPrank();

        // 투자자 화이트리스트 등록
        vm.startPrank(deployer);
        securityToken.addToWhitelist(investor1);
        securityToken.addToWhitelist(investor2);
        vm.stopPrank();

        // 투자자에게 SecurityToken 분배
        vm.startPrank(deployer);
        require(securityToken.transfer(investor1, 500), "Token transfer failed to investor1"); // 500 FTT
        require(securityToken.transfer(investor2, 300), "Token transfer failed to investor2"); // 300 FTT
        // deployer holds 200 FTT
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(address(distributor.securityToken()), address(securityToken), "SecurityToken address mismatch");
        assertEq(address(distributor.krwtToken()), address(krwt), "KRWT address mismatch");
        assertEq(distributor.owner(), deployer, "Owner mismatch");
        assertEq(distributor.MIN_TOTAL_DIVIDEND(), 1000, "MIN_TOTAL_DIVIDEND mismatch");
        assertEq(distributor.MIN_PER_SHARE(), 1, "MIN_PER_SHARE mismatch");
    }

    function testDistributeDividend_Success() public {
        uint256 totalDividendAmount = 10_000; // 10,000 KRWT
        address[] memory recipients = new address[](3);
        recipients[0] = deployer;
        recipients[1] = investor1;
        recipients[2] = investor2;

        // Admin이 Distributor에게 KRWT 사용 권한 부여
        vm.startPrank(deployer);
        krwt.approve(address(distributor), totalDividendAmount);
        vm.stopPrank();

        // 배당 실행
        vm.startPrank(deployer);
        (uint256 distributed, uint256 remainder) = distributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();

        // 검증
        assertEq(distributed, 10_000, "Total distributed amount mismatch");
        assertEq(remainder, 0, "Remainder should be 0");

        // 각 투자자 잔고 확인
        // deployer (200 FTT) -> (10000 * 200) / 1000 = 2000 KRWT
        // investor1 (500 FTT) -> (10000 * 500) / 1000 = 5000 KRWT
        // investor2 (300 FTT) -> (10000 * 300) / 1000 = 3000 KRWT
        assertEq(krwt.balanceOf(deployer), INITIAL_KRWT_MINT - totalDividendAmount + 2000, "Deployer KRWT balance mismatch");
        assertEq(krwt.balanceOf(investor1), 5000, "Investor1 KRWT balance mismatch");
        assertEq(krwt.balanceOf(investor2), 3000, "Investor2 KRWT balance mismatch");
        assertEq(krwt.balanceOf(address(distributor)), 0, "Distributor KRWT balance mismatch");
    }

    function testDistributeDividend_WithRemainder() public {
        uint256 totalDividendAmount = 9_999; // 9,999 KRWT (나머지 발생)
        address[] memory recipients = new address[](3);
        recipients[0] = deployer;
        recipients[1] = investor1;
        recipients[2] = investor2;

        // Admin이 Distributor에게 KRWT 사용 권한 부여
        vm.startPrank(deployer);
        krwt.approve(address(distributor), totalDividendAmount);
        vm.stopPrank();

        // 배당 실행
        vm.startPrank(deployer);
        (uint256 distributed, uint256 remainder) = distributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();

        // 검증
        assertEq(distributed, 9_990, "Total distributed amount mismatch (remainder)"); // 9999 / 1000 = 9.999 -> 9.99 * 1000 = 9990
        assertEq(remainder, 9, "Remainder should be 9"); // 9999 - 9990 = 9

        // 각 투자자 잔고 확인
        // deployer (200 FTT) -> (9999 * 200) / 1000 = 1999 KRWT
        // investor1 (500 FTT) -> (9999 * 500) / 1000 = 4999 KRWT
        // investor2 (300 FTT) -> (9999 * 300) / 1000 = 2999 KRWT
        assertEq(krwt.balanceOf(deployer), INITIAL_KRWT_MINT - totalDividendAmount + 1999 + remainder, "Deployer KRWT balance mismatch (remainder)");
        assertEq(krwt.balanceOf(investor1), 4999, "Investor1 KRWT balance mismatch (remainder)");
        assertEq(krwt.balanceOf(investor2), 2999, "Investor2 KRWT balance mismatch (remainder)");
        assertEq(krwt.balanceOf(address(distributor)), 0, "Distributor KRWT balance mismatch (remainder)");
    }

    function testDistributeDividend_Revert_NotOwner() public {
        uint256 totalDividendAmount = 10_000;
        address[] memory recipients = new address[](1);
        recipients[0] = investor1;

        vm.startPrank(deployer);
        krwt.approve(address(distributor), totalDividendAmount);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, investor1));
        vm.startPrank(investor1);
        distributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();
    }

    function testDistributeDividend_Revert_DividendTooSmall() public {
        uint256 totalDividendAmount = 999; // MIN_TOTAL_DIVIDEND = 1000
        address[] memory recipients = new address[](1);
        recipients[0] = deployer;

        vm.startPrank(deployer);
        krwt.approve(address(distributor), totalDividendAmount);
        vm.stopPrank();

        vm.expectRevert("Dividend too small");
        vm.startPrank(deployer);
        distributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();
    }

    function testDistributeDividend_Revert_NoRecipients() public {
        uint256 totalDividendAmount = 10_000;
        address[] memory recipients = new address[](0);

        vm.startPrank(deployer);
        krwt.approve(address(distributor), totalDividendAmount);
        vm.stopPrank();

        vm.expectRevert("No recipients");
        vm.startPrank(deployer);
        distributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();
    }

    function testDistributeDividend_Revert_NoTokensIssued() public {
        // 새로운 SecurityToken을 만들어서 totalSupply가 0인 상태로 테스트
        SecurityToken emptyToken = new SecurityToken("Empty", "EMT", 0, deployer);
        DividendDistributor emptyDistributor = new DividendDistributor(address(emptyToken), address(krwt), deployer);

        uint256 totalDividendAmount = 10_000;
        address[] memory recipients = new address[](1);
        recipients[0] = deployer;

        vm.startPrank(deployer);
        krwt.approve(address(emptyDistributor), totalDividendAmount);
        vm.stopPrank();

        vm.expectRevert("No tokens issued");
        vm.startPrank(deployer);
        emptyDistributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();
    }

    function testDistributeDividend_Revert_PerShareTooSmall() public {
        // 총 배당액 1000, 총 주식 1001 -> 1주당 0 KRWT
        uint256 totalDividendAmount = 1000;
        SecurityToken largeSupplyToken = new SecurityToken("Large", "LGS", 1001, deployer);
        DividendDistributor largeSupplyDistributor = new DividendDistributor(address(largeSupplyToken), address(krwt), deployer);

        address[] memory recipients = new address[](1);
        recipients[0] = deployer;

        vm.startPrank(deployer);
        krwt.approve(address(largeSupplyDistributor), totalDividendAmount);
        vm.stopPrank();

        vm.expectRevert("Per-share dividend too small");
        vm.startPrank(deployer);
        largeSupplyDistributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();
    }

    function testDistributeDividend_Revert_InsufficientKRWTBalanceInContract() public {
        uint256 totalDividendAmount = 10_000;
        address[] memory recipients = new address[](1);
        recipients[0] = deployer;

        // Admin이 approve는 했지만, 실제 KRWT 잔고가 부족한 경우
        vm.startPrank(deployer);
        krwt.approve(address(distributor), totalDividendAmount);
        // krwt.transfer(deployer, krwt.balanceOf(deployer)); // Admin 잔고를 0으로 만들어서 테스트 가능
        vm.stopPrank();

        // Admin의 KRWT 잔고를 0으로 만들고 테스트
        vm.startPrank(deployer);
        krwt.transfer(makeAddr("burner"), krwt.balanceOf(deployer));
        vm.stopPrank();

        vm.expectRevert("ERC20: insufficient allowance"); // approve는 했지만, transferFrom 시 Admin 잔고 부족
        vm.startPrank(deployer);
        distributor.distributeDividend(totalDividendAmount, recipients);
        vm.stopPrank();
    }

    function testSimulateDividend() public view {
        uint256 totalDividendAmount = 10_000;
        address[] memory recipients = new address[](3);
        recipients[0] = deployer;
        recipients[1] = investor1;
        recipients[2] = investor2;

        (bool canDistribute, string memory reason, uint256 totalDistributed, uint256 totalRemainder, uint256[] memory amounts) =
            distributor.simulateDividend(totalDividendAmount, recipients);

        assertTrue(canDistribute, "Simulation should indicate can distribute");
        assertEq(reason, "OK", "Simulation reason mismatch");
        assertEq(totalDistributed, 10_000, "Simulation distributed mismatch");
        assertEq(totalRemainder, 0, "Simulation remainder mismatch");
        assertEq(amounts.length, 3, "Simulation amounts length mismatch");
        assertEq(amounts[0], 2000, "Simulation deployer amount mismatch");
        assertEq(amounts[1], 5000, "Simulation investor1 amount mismatch");
        assertEq(amounts[2], 3000, "Simulation investor2 amount mismatch");
    }

    function testEmergencyWithdraw() public {
        uint256 initialDistributorBalance = krwt.balanceOf(address(distributor));
        assertEq(initialDistributorBalance, 0, "Distributor should start with 0 KRWT");

        // Admin이 Distributor에게 KRWT를 직접 보냄 (approve 없이)
        vm.startPrank(deployer);
        krwt.transfer(address(distributor), 5000);
        vm.stopPrank();

        assertEq(krwt.balanceOf(address(distributor)), 5000, "Distributor should have 5000 KRWT");

        // Owner가 긴급 출금
        vm.startPrank(deployer);
        distributor.emergencyWithdraw();
        vm.stopPrank();

        assertEq(krwt.balanceOf(address(distributor)), 0, "Distributor balance should be 0 after withdraw");
        assertEq(krwt.balanceOf(deployer), INITIAL_KRWT_MINT, "Deployer should get back KRWT");
    }
}