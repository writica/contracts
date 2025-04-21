// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./FactoryCampaign.sol";

/**
 * @title CampaignManager
 * @dev Manages campaign owners and their permissions to create campaigns
 */
contract CampaignManager is Ownable {
    // Events
    event CampaignOwnerAdded(address indexed owner);
    event CampaignOwnerRemoved(address indexed owner);
    event FactorySet(address indexed factory);

    // Factory contract for deploying campaigns
    FactoryCampaign public factory;

    // Mapping to track campaign owners
    mapping(address => bool) public campaignOwners;

    /**
     * @dev Constructor sets the deployer as the owner
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Sets the factory contract address
     * @param _factory The address of the factory contract
     */
    function setFactory(address _factory) external onlyOwner {
        require(
            _factory != address(0),
            "CampaignManager: Factory address cannot be zero"
        );
        factory = FactoryCampaign(_factory);
        emit FactorySet(_factory);
    }

    /**
     * @dev Adds a new campaign owner
     * @param _owner The address of the new campaign owner
     */
    function addCampaignOwner(address _owner) external onlyOwner {
        require(
            _owner != address(0),
            "CampaignManager: Owner address cannot be zero"
        );
        require(
            !campaignOwners[_owner],
            "CampaignManager: Already a campaign owner"
        );

        campaignOwners[_owner] = true;
        emit CampaignOwnerAdded(_owner);
    }

    /**
     * @dev Removes a campaign owner
     * @param _owner The address of the campaign owner to remove
     */
    function removeCampaignOwner(address _owner) external onlyOwner {
        require(
            campaignOwners[_owner],
            "CampaignManager: Not a campaign owner"
        );

        campaignOwners[_owner] = false;
        emit CampaignOwnerRemoved(_owner);
    }

    /**
     * @dev Creates a new campaign through the factory
     * @param _name The name of the campaign
     * @return The address of the newly created campaign contract
     */
    function createCampaign(
        string memory _name,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _totalReward
    ) external returns (address) {
        require(
            address(factory) != address(0),
            "CampaignManager: Factory not set"
        );
        require(
            campaignOwners[msg.sender],
            "CampaignManager: Caller is not a campaign owner"
        );
        require(
            _endDate > block.timestamp,
            "CampaignManager: End date must be in the future"
        );

        return
            factory.createCampaign(
                _name,
                _startDate,
                _endDate,
                _totalReward,
                msg.sender
            );
    }

    /**
     * @dev Returns all campaigns created by a specific owner
     * @param _owner The address of the campaign owner
     */
    function getCampaignsByOwner(
        address _owner
    ) external view returns (address[] memory) {
        require(
            address(factory) != address(0),
            "CampaignManager: Factory not set"
        );
        return factory.getCampaignsByOwner(_owner);
    }

    /**
     * @dev Returns all deployed campaigns
     */
    function getAllCampaigns() external view returns (address[] memory) {
        require(
            address(factory) != address(0),
            "CampaignManager: Factory not set"
        );
        return factory.getAllCampaigns();
    }

    /**
     * @dev Returns the total number of campaigns created
     */
    function getCampaignCount() external view returns (uint256) {
        require(
            address(factory) != address(0),
            "CampaignManager: Factory not set"
        );
        return factory.getCampaignCount();
    }
}
