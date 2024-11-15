// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/DANKFairLaunch.sol";
import "../src/DankToken.sol";

/**
 * @title DeployFairLaunch
 * @dev Deployment script for DANKFairLaunch contract
 */
contract DeployFairLaunch is Script {
    /**
     * @dev Empty setup function required by Forge script
     */
    function setUp() public {}

    /**
     * @dev Main deployment function
     * @notice Deploys DANKFairLaunch contract and sets up initial configuration
     * Requirements:
     * - MNEMONIC_PATH environment variable must be set for Ledger derivation path
     * - DANK_TOKEN_ADDRESS environment variable must be set with deployed DankToken address
     * - FEE_COLLECTOR_ADDRESS environment variable must be set with fee collector address
     * - BASESCAN_API_KEY environment variable must be set for verification
     */
    function run() public {
        address dankTokenAddress = vm.envAddress("DANK_TOKEN_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");
        
        vm.startBroadcast();

        DANKFairLaunch fairLaunch = new DANKFairLaunch(
            dankTokenAddress,
            feeCollector
        );
        
        console.log("DANKFairLaunch deployed to:", address(fairLaunch));
        console.log("DANK Token:", dankTokenAddress);
        console.log("Fee Collector:", feeCollector);

        vm.stopBroadcast();
    }
} 