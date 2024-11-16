// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/DankToken.sol";

/**
 * @title DeployHub
 * @dev Deployment script for DankToken contract
 */
contract DeployHub is Script {
    // Constants
    string constant TOKEN_NAME = "Dank";
    string constant TOKEN_SYMBOL = "DANK";

    /**
     * @dev Empty setup function required by Forge script
     */
    function setUp() public {}

    /**
     * @dev Main deployment function
     * @notice Deploys DankToken contract and mints initial supply
     * Requirements:
     * - PRIVATE_KEY environment variable must be set with deployer's private key
     * - INITIAL_HOLDER environment variable must be set with initial token holder address
     */
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialHolder = vm.envAddress("INITIAL_HOLDER");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        
        vm.startBroadcast(deployerPrivateKey);

        DankToken token = new DankToken(
            TOKEN_NAME, 
            TOKEN_SYMBOL,
            initialHolder,
            maxSupply
        );
        
        console.log("Dank Token deployed to:", address(token));
        console.log("Initial tokens minted to:", initialHolder);
        console.log("Total supply:", maxSupply);

        vm.stopBroadcast();
    }
}
