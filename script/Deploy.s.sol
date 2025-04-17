// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/FactoryCampaign.sol";
import "../src/CampaignManager.sol";

/**
 * @title DeployScript
 * @dev Script for deploying the campaign contracts
 */
contract DeployScript is Script {
    function run() external {
        // Get the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the factory contract
        FactoryCampaign factory = new FactoryCampaign();
        console2.log("Factory deployed at:", address(factory));
        
        // Deploy the manager contract
        CampaignManager manager = new CampaignManager();
        console2.log("Manager deployed at:", address(manager));
        
        // Set the factory in the manager
        manager.setFactory(address(factory));
        console2.log("Factory set in manager");
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
} 