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
 * forge script script/Deploy.s.sol:DeployScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
 */
contract DeployScript is Script {
    function run() external {
        // === Configuration ===
        // IMPORTANT: Replace this with the actual admin address that will own the contracts.
        // This should ideally be a secure multi-sig wallet address.
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");
        if (adminAddress == address(0)) {
            adminAddress = msg.sender; // Fallback to deployer if not set
        }

        // === Deployment ===
        vm.startBroadcast();

        console.log("Deploying KRWT contract...");
        KRWT krwt = new KRWT();
        console.log("KRWT contract deployed at:", address(krwt));

        console.log("Deploying TokenFactory contract...");
        TokenFactory factory = new TokenFactory(address(krwt), adminAddress);
        console.log("TokenFactory contract deployed at:", address(factory));
        
        vm.stopBroadcast();

        // === Post-Deployment Information ===
        console.log("\n--- Deployment Summary ---");
        console.log("Platform Admin Address:", adminAddress);
        console.log("KRWT Contract Address:", address(krwt));
        console.log("TokenFactory Contract Address:", address(factory));
        console.log("\nConfiguration for backend application:");
        console.log("KRWT_CONTRACT_ADDRESS=%s", address(krwt));
        console.log("TOKEN_FACTORY_CONTRACT_ADDRESS=%s", address(factory));
        console.log("--------------------------\n");
    }
}
