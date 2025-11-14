// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {KRWT} from "../src/KRWT.sol";
import {TokenFactory} from "../src/TokenFactory.sol";

/**
 * @notice Deploys the core contracts (KRWT, TokenFactory) for the IPiece platform.
 * @dev After running this script, the outputted contract addresses should be
 *      used to configure the backend application.
 *
 * To run this script:
 * ADMIN_ADDRESS=0x... forge script script/Deploy.s.sol:DeployScript \
 *   --rpc-url http://172.16.4.60:8545 \
 *   --private-key 0x... \
 *   --broadcast --legacy
 */
contract DeployScript is Script {
    // 1000조 KRWT (10^15 KRWT * 10^18 decimals = 10^33 wei)
    uint256 public constant KRWT_CAP = 1_000_000_000_000_000_000_000_000_000_000_000; // 10^33

    function run() external {
        // 환경 변수에서 관리자 주소 가져오기
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");
        
        // Fallback: 환경 변수 없으면 배포자 사용
        if (adminAddress == address(0)) {
            console.log("WARNING: ADMIN_ADDRESS not set, using deployer");
            adminAddress = msg.sender;
        }
        
        vm.startBroadcast();
        
        console.log("=== IPiece Smart Contract Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Admin:   ", adminAddress);
        console.log("");
        
        // 1. KRWT 배포
        console.log("1. Deploying KRWT...");
        KRWT krwt = new KRWT(KRWT_CAP);
        console.log("   Address:", address(krwt));
        
        // 소유권 이전
        krwt.transferOwnership(adminAddress);
        console.log("   Owner transferred to admin");
        console.log("");
        
        // 2. TokenFactory 배포 (수정: 1개 파라미터만!)
        console.log("2. Deploying TokenFactory...");
        TokenFactory factory = new TokenFactory(address(krwt));
        console.log("   Address:", address(factory));
        
        // 소유권 이전 (추가!)
        factory.transferOwnership(adminAddress);
        console.log("   Owner transferred to admin");
        console.log("");
        
        vm.stopBroadcast();
        
        // === Post-Deployment Summary ===
        console.log("=== Deployment Complete! ===");
        console.log("");
        console.log("Deployed Contracts:");
        console.log("  KRWT:         ", address(krwt));
        console.log("  TokenFactory: ", address(factory));
        console.log("");
        console.log("Owner:           ", adminAddress);
        console.log("");
        console.log("Backend Configuration:");
        console.log("  KRWT_CONTRACT_ADDRESS=%s", address(krwt));
        console.log("  TOKEN_FACTORY_CONTRACT_ADDRESS=%s", address(factory));
        console.log("");
    }
}
