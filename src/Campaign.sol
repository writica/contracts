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
    // Campaign name
    string public name;

    struct Contribution {
        address contributor; // The address of the contributor for this record
        uint256 amount;      // The current amount locked in this contribution record
    }

    // --- State Variables ---

    IERC20 public immutable token; // The ERC20 token being managed for the campaign

    // Mapping from contribution ID to the contribution details
    mapping(uint256 => Contribution) public contributions;

    // Counter to generate unique contribution IDs (starts from 1)
    uint256 private _nextContributionId = 1;

    // Tax configuration
    address public taxAddress;
    uint256 public taxPercentageBps; // Tax percentage in Basis Points (1% = 100, 5% = 500, 100% = 10000)

    // --- Constants ---
    uint256 public constant MAX_TAX_BPS = 10000; // Maximum basis points (100%)

    // --- Events ---

    event Contributed(address indexed contributor, uint256 indexed contributionId, uint256 amount);
    event ContributionIncreased(uint256 indexed contributionId, uint256 additionalAmount, uint256 newTotalAmount);
    event ContributionRefunded(uint256 indexed contributionId, address indexed contributor, uint256 refundedAmount, uint256 remainingAmount);
    event ContributionClosed(uint256 indexed contributionId); // Emitted when a contribution is fully refunded
    event Distributed(address[] recipients, uint256[] amounts, uint256 taxAmount);
    event TaxAddressSet(address indexed newTaxAddress);
    event TaxPercentageSet(uint256 newTaxPercentageBps);
    event CampaignNameUpdated(string newName);

    // --- Constructor ---

    /**
     * @dev Sets the campaign name, ERC20 token, initial tax address, and tax percentage.
     * @param _name The name of the campaign
     * @param _tokenAddress The address of the ERC20 token contract.
     * @param _initialTaxAddress The initial address to receive distribution tax.
     * @param _initialTaxPercentageBps The initial tax rate in basis points (e.g., 500 for 5%).
     */
    constructor(
        string memory _name,
        address _tokenAddress,
        address _initialTaxAddress,
        uint256 _initialTaxPercentageBps
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Campaign: Token address cannot be zero");
        require(_initialTaxPercentageBps <= MAX_TAX_BPS, "Campaign: Initial tax exceeds maximum");

        name = _name;
        token = IERC20(_tokenAddress);
        taxAddress = _initialTaxAddress;
        taxPercentageBps = _initialTaxPercentageBps;
    }

    // --- Owner Functions ---

    /**
     * @dev Updates the campaign name
     * @param _newName The new name for the campaign
     */
    function updateCampaignName(string memory _newName) external onlyOwner {
        name = _newName;
        emit CampaignNameUpdated(_newName);
    }

    /**
     * @dev Sets the address where distribution taxes are sent.
     * @param _newTaxAddress The new address for tax collection.
     */
    function setTaxAddress(address _newTaxAddress) external onlyOwner {
        taxAddress = _newTaxAddress;
        emit TaxAddressSet(_newTaxAddress);
    }

    /**
     * @dev Sets the tax percentage in basis points (1/100th of a percent).
     * @param _newTaxPercentageBps The new tax rate (e.g., 500 for 5%). Max 10000.
     */
    function setTaxPercentage(uint256 _newTaxPercentageBps) external onlyOwner {
        require(_newTaxPercentageBps <= MAX_TAX_BPS, "Campaign: Tax percentage exceeds maximum");
        taxPercentageBps = _newTaxPercentageBps;
        emit TaxPercentageSet(_newTaxPercentageBps);
    }

    // --- Contributor Functions ---

    /**
     * @dev Creates a new contribution record for the caller (contributor).
     * Contributor MUST have approved this contract to spend at least `_amount`.
     * @param _amount The amount of tokens to contribute.
     * @return contributionId The ID of the newly created contribution record.
     */
    function contribute(uint256 _amount) external nonReentrant returns (uint256 contributionId) {
        require(_amount > 0, "Campaign: Contribution amount must be positive");        
        // Get current ID and increment the counter for the next one
        contributionId = _nextContributionId;
        _nextContributionId = _nextContributionId + 1;

        // Create and store the new contribution record
        contributions[contributionId] = Contribution({
            contributor: msg.sender,
            amount: _amount
        });

        // Transfer tokens from contributor to this contract
        _safeTransferFrom(msg.sender, address(this), _amount);

        emit Contributed(msg.sender, contributionId, _amount);
        return contributionId;
    }

    /**
     * @dev Adds more funds to an existing contribution record owned by the caller.
     * Contributor MUST have approved this contract to spend at least `_additionalAmount`.
     * @param _contributionId The ID of the contribution record to top up.
     * @param _additionalAmount The amount of tokens to add.
     */
    function addToContribution(uint256 _contributionId, uint256 _additionalAmount) external nonReentrant {
        require(_additionalAmount > 0, "Campaign: Added amount must be positive");

        Contribution storage record = contributions[_contributionId]; // Get storage pointer        
        require(record.contributor != address(0), "Campaign: Contribution record does not exist");
        require(record.contributor == msg.sender, "Campaign: Caller is not the contributor for this record");

        // Update the amount *before* transfer (Checks-Effects-Interactions)
        record.amount = record.amount + _additionalAmount;

        // Transfer tokens from contributor to this contract
        _safeTransferFrom(msg.sender, address(this), _additionalAmount);

        emit ContributionIncreased(_contributionId, _additionalAmount, record.amount);
    }

    /**
     * @dev Refunds funds from a specific contribution record back to the original contributor.
     * Can refund partial or full amount. If full amount is refunded, the record is deleted.
     * @param _contributionId The ID of the contribution record to refund funds from.
     * @param _amount The amount to refund (cannot exceed the record's current amount).
     */
    function refundContribution(uint256 _contributionId, uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Campaign: Refund amount must be positive");

        Contribution storage record = contributions[_contributionId]; // Get storage pointer

        require(record.contributor != address(0), "Campaign: Contribution record does not exist");        
        require(record.amount >= _amount, "Campaign: Refund amount exceeds contribution balance");

        address contributor = record.contributor; // Cache contributor address
        uint256 remainingAmount = record.amount - _amount;

        // Update state *before* transfer
        record.amount = remainingAmount;

        // If the entire amount is refunded, delete the record to save gas
        if (remainingAmount == 0) {
            delete contributions[_contributionId];
            emit ContributionClosed(_contributionId);
        }

        // Transfer tokens back to the contributor
        _safeTransfer(contributor, _amount);

        emit ContributionRefunded(_contributionId, contributor, _amount, remainingAmount);
    }

    /**
     * @dev Distributes funds to multiple recipients with a tax applied.
     * @param _recipients Array of recipient addresses.
     * @param _amounts Array of amounts to distribute to each recipient.
     */
    function distribute(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner nonReentrant {
        require(_recipients.length == _amounts.length, "Campaign: Recipients and amounts arrays must have the same length");
        require(_recipients.length > 0, "Campaign: Must have at least one recipient");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        uint256 taxAmount = (totalAmount * taxPercentageBps) / MAX_TAX_BPS;
        uint256 totalWithTax = totalAmount + taxAmount;

        require(totalWithTax <= token.balanceOf(address(this)), "Campaign: Insufficient balance for distribution");

        // Transfer tax first
        if (taxAmount > 0) {
            _safeTransfer(taxAddress, taxAmount);
        }

        // Transfer to recipients
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_amounts[i] > 0) {
                _safeTransfer(_recipients[i], _amounts[i]);
            }
        }

        emit Distributed(_recipients, _amounts, taxAmount);
    }

    // --- View Functions ---

    /**
     * @dev Gets the details of a specific contribution record.
     * @param _contributionId The ID of the contribution record.
     * @return contributor The address of the contributor.
     * @return amount The current amount locked in the record.
     */
    function getContribution(uint256 _contributionId) external view returns (address contributor, uint256 amount) {
        Contribution storage record = contributions[_contributionId];
        return (record.contributor, record.amount);
    }

    /**
     * @dev Gets the next available contribution ID.
     */
    function getNextContributionId() external view returns (uint256) {
        return _nextContributionId;
    }

    /**
     * @dev Gets the total balance of the managed token held by this contract.
     */
    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // --- Internal Helper Functions ---

    /**
     * @dev Internal function for safely transferring tokens from this contract.
     */
    function _safeTransfer(address _to, uint256 _amount) internal {
        bool success = token.transfer(_to, _amount);
        require(success, "Campaign: ERC20 transfer failed");
    }

     /**
     * @dev Internal function for safely transferring tokens to this contract.
     */
    function _safeTransferFrom(address _from, address _to, uint256 _amount) internal {
        bool success = token.transferFrom(_from, _to, _amount);
        require(success, "Campaign: ERC20 transferFrom failed. Check allowance.");
    }
}