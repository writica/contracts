// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/FactoryCampaign.sol";
import "../src/CampaignManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BlogToken is ERC20 {
    constructor() ERC20("BLOG Token", "BLOG") {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1 million tokens to deployer
    }

    function mint(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= 1000 * 10 ** 18, "Max 1000 tokens can be minted");

        _mint(msg.sender, amount);
    }
}

/**
 * @title DeployScript
 * @dev Script for deploying the campaign contracts
 */
contract DeployScript is Script {
    uint256 constant TAX_PERCENTAGE = 500; // 5%
    address constant TAX_ADDRESS = 0x9EF7a9d46C4F3EC4378D3dD495E827F0D1cb475E;

    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast();

        BlogToken rewardToken = new BlogToken();

        // Deploy the factory contract
        FactoryCampaign factory = new FactoryCampaign(
            address(rewardToken),
            TAX_ADDRESS,
            TAX_PERCENTAGE
        );
        console2.log("Factory deployed at:", address(factory));

        // Deploy the manager contract
        CampaignManager manager = new CampaignManager();
        console2.log("Manager deployed at:", address(manager));

        // Set the factory in the manager
        manager.setFactory(address(factory));
        console2.log("Factory set in manager");

        factory.setCampaignManager(address(manager));
        console2.log("Manager set in factory");

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
