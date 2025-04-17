// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {CampaignManager} from "../src/CampaignManager.sol";
import {FactoryCampaign} from "../src/FactoryCampaign.sol";
import {Campaign} from "../src/Campaign.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1 million tokens to deployer
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract CampaignManagerTest is Test {
    CampaignManager public manager;
    FactoryCampaign public factory;
    MockToken public token;
    
    address public owner;
    address public campaignOwner;
    address public contributor;
    address public taxCollector;
    
    uint256 public constant INITIAL_TOKEN_AMOUNT = 10000 * 10**18; // 10,000 tokens
    uint256 public constant TAX_PERCENTAGE = 500; // 5%
    
    event CampaignOwnerAdded(address indexed owner);
    event CampaignOwnerRemoved(address indexed owner);
    event FactorySet(address indexed factory);
    
    function setUp() public {
        // Set up accounts
        owner = address(this);
        campaignOwner = makeAddr("campaignOwner");
        contributor = makeAddr("contributor");
        taxCollector = makeAddr("taxCollector");
        
        // Deploy contracts
        factory = new FactoryCampaign();
        manager = new CampaignManager();
        
        // Set up the manager
        manager.setFactory(address(factory));
        
        // Deploy and set up token
        token = new MockToken();
        token.transfer(contributor, INITIAL_TOKEN_AMOUNT);
        
        // Add campaign owner
        manager.addCampaignOwner(campaignOwner);
    }
    
    function test_Deployment() public {
        assertEq(address(manager.factory()), address(factory));
        assertTrue(manager.campaignOwners(campaignOwner));
        assertFalse(manager.campaignOwners(contributor));
    }
    
    function test_AddCampaignOwner() public {
        address newOwner = makeAddr("newOwner");
        
        vm.expectEmit(true, false, false, true);
        emit CampaignOwnerAdded(newOwner);
        manager.addCampaignOwner(newOwner);
        
        assertTrue(manager.campaignOwners(newOwner));
    }
    
    function test_RemoveCampaignOwner() public {
        vm.expectEmit(true, false, false, true);
        emit CampaignOwnerRemoved(campaignOwner);
        manager.removeCampaignOwner(campaignOwner);
        
        assertFalse(manager.campaignOwners(campaignOwner));
    }
    
    function test_CreateCampaign() public {
        // Switch to campaign owner
        vm.startPrank(campaignOwner);
        
        // Create a campaign
        address campaignAddress = manager.createCampaign(
            "Test Campaign",
            address(token),
            taxCollector,
            TAX_PERCENTAGE
        );
        
        // Verify campaign was created
        assertTrue(campaignAddress != address(0));
        
        // Get the campaign contract
        Campaign campaign = Campaign(campaignAddress);
        
        // Verify campaign properties
        assertEq(campaign.name(), "Test Campaign");
        assertEq(address(campaign.token()), address(token));
        assertEq(campaign.taxAddress(), taxCollector);
        assertEq(campaign.taxPercentageBps(), TAX_PERCENTAGE);
        
        vm.stopPrank();
    }
    
    function test_NonCampaignOwnerCannotCreateCampaign() public {
        // Switch to contributor (not a campaign owner)
        vm.startPrank(contributor);
        
        // Try to create a campaign (should fail)
        vm.expectRevert("CampaignManager: Caller is not a campaign owner");
        manager.createCampaign(
            "Test Campaign",
            address(token),
            taxCollector,
            TAX_PERCENTAGE
        );
        
        vm.stopPrank();
    }
    
    function test_GetCampaignsByOwner() public {
        // Switch to campaign owner
        vm.startPrank(campaignOwner);
        
        // Create a campaign
        address campaignAddress = manager.createCampaign(
            "Test Campaign",
            address(token),
            taxCollector,
            TAX_PERCENTAGE
        );
        
        // Get campaigns by owner
        address[] memory campaigns = manager.getCampaignsByOwner(campaignOwner);
        
        // Verify
        assertEq(campaigns.length, 1);
        assertEq(campaigns[0], campaignAddress);
        
        // Verify campaign count
        uint256 count = manager.getCampaignCount();
        console2.log("Campaign count:", count);
        console2.log("Campaign address:", campaignAddress);
        
        // Check factory directly
        uint256 factoryCount = factory.getCampaignCount();
        console2.log("Factory campaign count:", factoryCount);
        
        assertEq(count, 1);
        
        vm.stopPrank();
    }
    
    function test_GetAllCampaigns() public {
        // Switch to campaign owner
        vm.startPrank(campaignOwner);
        
        // Create a campaign
        address campaignAddress = manager.createCampaign(
            "Test Campaign",
            address(token),
            taxCollector,
            TAX_PERCENTAGE
        );
        
        // Get all campaigns
        address[] memory campaigns = manager.getAllCampaigns();
        
        // Verify
        assertEq(campaigns.length, 1);
        assertEq(campaigns[0], campaignAddress);
        
        vm.stopPrank();
    }
    
    function test_GetCampaignCount() public {
        // Switch to campaign owner
        vm.startPrank(campaignOwner);
        
        // Create a campaign
        manager.createCampaign(
            "Test Campaign",
            address(token),
            taxCollector,
            TAX_PERCENTAGE
        );
        
        // Get campaign count
        uint256 count = manager.getCampaignCount();
        
        // Verify
        assertEq(count, 1);
        
        vm.stopPrank();
    }
} 