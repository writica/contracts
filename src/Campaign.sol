// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Campaign
 * @dev Manages individual contribution records with unique IDs for contributors.
 * Allows contributors to make contributions and add to them.
 * Owner can refund specific contributions and distribute pooled funds
 * with a configurable tax applied to distributions.
 */
contract Campaign is Ownable, ReentrancyGuard {
    // --- Events ---

    event TaxAddressSet(address indexed newTaxAddress);
    event TaxPercentageSet(uint256 newTaxPercentageBps);
    event CampaignNameUpdated(string newName);
    event CampaignDateUpdated(uint256 startDate, uint256 endDate);
    event CampaignRewardUpdated(uint256 totalReward);
    event CampaignConfigured(uint256 start, uint256 end);
    event RewardDeposited(uint256 amount);
    event ContributorAdded(address[] contributors, uint256[] scores);
    event SingleContributorAdded(address contributor, uint256 score);
    event RewardWithdrawn(address contributor, uint256 amount);

    struct Contribution {
        address contributor; // The address of the contributor for this record
        uint256 amount; // The current amount locked in this contribution record
    }

    string public name;
    address public campaignManager;
    uint256 public campaignStart;
    uint256 public campaignEnd;
    bool public rewardsDeposited;
    uint256 public totalReward;
    uint256 public totalScore;

    mapping(address => uint256) public scores;
    mapping(address => bool) public hasWithdrawn;

    // Tax configuration
    IERC20 public rewardAddress;
    address public taxAddress;
    uint256 public taxPercentageBps; // Tax percentage in Basis Points (1% = 100, 5% = 500, 100% = 10000)

    // --- Constants ---
    uint256 public constant MAX_TAX_BPS = 10000; // Maximum basis points (100%)

    // --- Modifier ---

    modifier campaignEnded() {
        require(block.timestamp > campaignEnd, "Campaign not ended");
        _;
    }

    modifier campaignStarted() {
        require(block.timestamp > campaignStart, "Campaign not started");
        _;
    }

    modifier onlyCampaignManager() {
        require(campaignManager == msg.sender, "Only campaign manager allowed");
        _;
    }

    // --- Constructor ---

    /**
     * @dev Sets the campaign name, ERC20 token, initial tax address, and tax percentage.
     * @param _name The name of the campaign
     * @param _startDate The start date of the campaign (in seconds since epoch).
     * @param _endDate The end date of the campaign (in seconds since epoch).
     * @param _totalReward The total reward amount for the campaign.
     * @param _rewardAddress The address of the ERC20 token contract.
     * @param _initialTaxAddress The initial address to receive distribution tax.
     * @param _initialTaxPercentageBps The initial tax rate in basis points (e.g., 500 for 5%).
     */
    constructor(
        string memory _name,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _totalReward,
        address _rewardAddress,
        address _initialTaxAddress,
        uint256 _initialTaxPercentageBps,
        address _campaignOwner,
        address _campaignManager
    ) Ownable(_campaignOwner) {
        require(
            _rewardAddress != address(0),
            "Campaign: Token address cannot be zero"
        );
        require(
            _initialTaxPercentageBps <= MAX_TAX_BPS,
            "Campaign: Initial tax exceeds maximum"
        );

        name = _name;
        campaignStart = _startDate;
        campaignEnd = _endDate;
        totalReward = _totalReward;
        rewardsDeposited = false;

        rewardAddress = IERC20(_rewardAddress);
        taxAddress = _initialTaxAddress;
        taxPercentageBps = _initialTaxPercentageBps;
        campaignManager = _campaignManager;
    }

    /**
     * @dev Updates the campaign name
     * @param _newName The new name for the campaign
     */
    function updateCampaignName(string memory _newName) external onlyOwner {
        name = _newName;
        emit CampaignNameUpdated(_newName);
    }

    /**
     * @dev Updates the campaign date
     * @param _startDate The start date for the campaign
     * @param _endDate The end date for the campaign
     */
    function updateCampaignDate(
        uint256 _startDate,
        uint256 _endDate
    ) external onlyOwner {
        require(
            _endDate > block.timestamp,
            "CampaignManager: End date must be in the future"
        );

        campaignStart = _startDate;
        campaignEnd = _endDate;

        emit CampaignDateUpdated(_startDate, _endDate);
    }

    /**
     * @dev Updates the campaign reward
     * @param _totalReward The total reward for the campaign
     */
    function updateCampaignReward(uint256 _totalReward) external onlyOwner {
        require(
            campaignStart > block.timestamp,
            "CampaignManager: Campaign already started"
        );

        totalReward = _totalReward;
        emit CampaignRewardUpdated(_totalReward);
    }

    /**
     * @dev Sets the address where distribution taxes are sent.
     * @param _newTaxAddress The new address for tax collection.
     */
    function setTaxAddress(
        address _newTaxAddress
    ) external onlyCampaignManager {
        taxAddress = _newTaxAddress;
        emit TaxAddressSet(_newTaxAddress);
    }

    /**
     * @dev Sets the tax percentage in basis points (1/100th of a percent).
     * @param _newTaxPercentageBps The new tax rate (e.g., 500 for 5%). Max 10000.
     */
    function setTaxPercentage(
        uint256 _newTaxPercentageBps
    ) external onlyCampaignManager {
        require(
            _newTaxPercentageBps <= MAX_TAX_BPS,
            "Campaign: Tax percentage exceeds maximum"
        );
        taxPercentageBps = _newTaxPercentageBps;
        emit TaxPercentageSet(_newTaxPercentageBps);
    }

    function depositReward() external onlyOwner {
        require(!rewardsDeposited, "Already deposited");

        uint256 taxAmount = (totalReward * taxPercentageBps) / MAX_TAX_BPS;
        uint256 netAmount = totalReward - taxAmount;

        rewardAddress.transferFrom(msg.sender, address(this), totalReward);

        // Forward tax to treasury
        if (taxAmount > 0) {
            rewardAddress.transfer(taxAddress, taxAmount);
        }

        totalReward = netAmount;
        rewardsDeposited = true;

        emit RewardDeposited(totalReward);
    }

    function addContributors(
        address[] calldata _contributors,
        uint256[] calldata _scores
    ) external onlyOwner {
        require(_contributors.length == _scores.length, "Mismatched input");
        for (uint256 i = 0; i < _contributors.length; i++) {
            address contributor = _contributors[i];
            uint256 score = _scores[i];
            if (scores[contributor] == 0) {
                totalScore += score;
                scores[contributor] = score;
            }
        }
        emit ContributorAdded(_contributors, _scores);
    }

    function addContributor(
        address _contributor,
        uint256 _score
    ) external onlyOwner {
        if (scores[_contributor] == 0) {
            totalScore += _score;
            scores[_contributor] = _score;
        }
        emit SingleContributorAdded(_contributor, _score);
    }

    function withdraw() external {
        require(rewardsDeposited, "Rewards not deposited");
        require(!hasWithdrawn[msg.sender], "Already withdrawn");
        uint256 score = scores[msg.sender];
        require(score > 0, "No score");

        uint256 share = (totalReward * score) / totalScore;
        hasWithdrawn[msg.sender] = true;
        rewardAddress.transfer(msg.sender, share);

        emit RewardWithdrawn(msg.sender, share);
    }
}
