// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Campaign.sol";

/**
 * @title FactoryCampaign
 * @dev Factory contract for deploying new campaign contracts
 */
contract FactoryCampaign is Ownable {
    // Array to keep track of all deployed campaigns
    address[] public deployedCampaigns;
    
    // Mapping from campaign owner to their campaigns
    mapping(address => address[]) public ownerCampaigns;
    
    // Event emitted when a new campaign is created
    event CampaignCreated(address indexed campaignAddress, address indexed campaignOwner, string name);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Creates a new campaign contract
     * @param _name The name of the campaign
     * @param _tokenAddress The address of the ERC20 token to be used for the campaign
     * @param _taxAddress The address where taxes will be sent
     * @param _taxPercentageBps The tax percentage in basis points (1% = 100)
     * @return The address of the newly created campaign contract
     */
    function createCampaign(
        string memory _name,
        address _tokenAddress,
        address _taxAddress,
        uint256 _taxPercentageBps
    ) external returns (address) {
        // Deploy a new campaign contract
        Campaign newCampaign = new Campaign(
            _name,
            _tokenAddress,
            _taxAddress,
            _taxPercentageBps
        );
        
        // Transfer ownership of the campaign to the caller
        newCampaign.transferOwnership(msg.sender);
        
        // Add the campaign to our tracking arrays
        deployedCampaigns.push(address(newCampaign));
        ownerCampaigns[msg.sender].push(address(newCampaign));
        
        // Emit event
        emit CampaignCreated(address(newCampaign), msg.sender, _name);
        
        return address(newCampaign);
    }
    
    /**
     * @dev Returns the total number of campaigns created
     */
    function getCampaignCount() external view returns (uint256) {
        return deployedCampaigns.length;
    }
    
    /**
     * @dev Returns all campaigns created by a specific owner
     * @param _owner The address of the campaign owner
     */
    function getCampaignsByOwner(address _owner) external view returns (address[] memory) {
        return ownerCampaigns[_owner];
    }
    
    /**
     * @dev Returns all deployed campaigns
     */
    function getAllCampaigns() external view returns (address[] memory) {
        return deployedCampaigns;
    }
} 