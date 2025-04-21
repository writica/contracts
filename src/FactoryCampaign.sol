// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Campaign.sol";

/**
 * @title FactoryCampaign
 * @dev Factory contract for deploying new campaign contracts
 */
contract FactoryCampaign is Ownable {
    // Event emitted when a new campaign is created
    event CampaignCreated(
        address indexed campaignAddress,
        address indexed campaignOwner,
        string name
    );

    event CampaignManagerCreated(address indexed campaignManagerAddress);

    // Array to keep track of all deployed campaigns
    address[] public deployedCampaigns;

    // Mapping from campaign owner to their campaigns
    mapping(address => address[]) public ownerCampaigns;

    address public defaultRewardAddress;
    address public defaultTaxAddress;
    uint256 public defaultTaxPercentageBps = 10000;

    address campaignManager;

    modifier onlyCampaignManager() {
        require(campaignManager == msg.sender, "Only campaign manager allowed");
        _;
    }
    constructor(
        address _defaultRewardAddress,
        address _defaultTaxAddress,
        uint256 _defaultTaxPercentageBps
    ) Ownable(msg.sender) {
        require(
            _defaultRewardAddress != address(0),
            "CampaignManager: Default reward address cannot be zero"
        );

        require(
            _defaultTaxAddress != address(0),
            "CampaignManager: Default tax address cannot be zero"
        );

        defaultRewardAddress = _defaultRewardAddress;
        defaultTaxAddress = _defaultTaxAddress;
        defaultTaxPercentageBps = _defaultTaxPercentageBps;
    }

    /**
     * @dev Creates a new campaign contract
     * @param _name The name of the campaign
     * @param _startDate The start date of the campaign (in seconds since epoch).
     * @param _endDate The end date of the campaign (in seconds since epoch).
     * @param _totalReward The total reward amount for the campaign.
     * @param _campaignOwner The campaign owner.
     */
    function createCampaign(
        string memory _name,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _totalReward,
        address _campaignOwner
    ) external onlyCampaignManager returns (address) {
        require(
            campaignManager != address(0),
            "CampaignManager: Campaign manager address cannot be zero"
        );

        // Deploy a new campaign contract
        Campaign newCampaign = new Campaign(
            _name,
            _startDate,
            _endDate,
            _totalReward,
            defaultRewardAddress,
            defaultTaxAddress,
            defaultTaxPercentageBps,
            _campaignOwner,
            campaignManager
        );

        // Add the campaign to our tracking arrays
        deployedCampaigns.push(address(newCampaign));
        ownerCampaigns[_campaignOwner].push(address(newCampaign));

        emit CampaignCreated(address(newCampaign), _campaignOwner, _name);

        return address(newCampaign);
    }

    /**
     * @dev Create campaign manager address
     */
    function setCampaignManager(address _campaignManager) external onlyOwner {
        require(
            _campaignManager != address(0),
            "CampaignManager: Campaign manager address cannot be zero"
        );

        campaignManager = _campaignManager;

        // Emit event
        emit CampaignManagerCreated(campaignManager);
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
    function getCampaignsByOwner(
        address _owner
    ) external view returns (address[] memory) {
        return ownerCampaigns[_owner];
    }

    /**
     * @dev Returns all deployed campaigns
     */
    function getAllCampaigns() external view returns (address[] memory) {
        return deployedCampaigns;
    }
}
