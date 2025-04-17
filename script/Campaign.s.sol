// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CampaignFund
 * @dev Manages individual contribution records with unique IDs for contributors.
 * Allows contributors to make contributions and add to them.
 * Owner can refund specific contributions and distribute pooled funds
 * with a configurable tax applied to distributions.
 */
contract CampaignFund is Ownable, ReentrancyGuard {

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

    // --- Constructor ---

    /**
     * @dev Sets the ERC20 token, initial tax address, and tax percentage.
     * @param _tokenAddress The address of the ERC20 token contract.
     * @param _initialTaxAddress The initial address to receive distribution tax.
     * @param _initialTaxPercentageBps The initial tax rate in basis points (e.g., 500 for 5%).
     */
    constructor(address _tokenAddress, address _initialTaxAddress, uint256 _initialTaxPercentageBps) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "CampaignFund: Token address cannot be zero");
        require(_initialTaxPercentageBps <= MAX_TAX_BPS, "CampaignFund: Initial tax exceeds maximum");

        token = IERC20(_tokenAddress);
        taxAddress = _initialTaxAddress;
        taxPercentageBps = _initialTaxPercentageBps;
    }

    // --- Contributor Functions ---

    /**
     * @dev Creates a new contribution record for the caller (contributor).
     * Contributor MUST have approved this contract to spend at least `_amount`.
     * @param _amount The amount of tokens to contribute.
     * @return contributionId The ID of the newly created contribution record.
     */
    function contribute(uint256 _amount) external nonReentrant returns (uint256 contributionId) {
        require(_amount > 0, "CampaignFund: Contribution amount must be positive");        
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
        require(_additionalAmount > 0, "CampaignFund: Added amount must be positive");

        Contribution storage record = contributions[_contributionId]; // Get storage pointer        
        require(record.contributor != address(0), "CampaignFund: Contribution record does not exist");
        require(record.contributor == msg.sender, "CampaignFund: Caller is not the contributor for this record");

        // Update the amount *before* transfer (Checks-Effects-Interactions)
        record.amount = record.amount + _additionalAmount;

        // Transfer tokens from contributor to this contract
        _safeTransferFrom(msg.sender, address(this), _additionalAmount);

        emit ContributionIncreased(_contributionId, _additionalAmount, record.amount);
    }

    // --- Owner Functions ---

    /**
     * @dev Refunds funds from a specific contribution record back to the original contributor.
     * Can refund partial or full amount. If full amount is refunded, the record is deleted.
     * @param _contributionId The ID of the contribution record to refund funds from.
     * @param _amount The amount to refund (cannot exceed the record's current amount).
     */
    function refundContribution(uint256 _contributionId, uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "CampaignFund: Refund amount must be positive");

        Contribution storage record = contributions[_contributionId]; // Get storage pointer

        require(record.contributor != address(0), "CampaignFund: Contribution record does not exist");        
        require(record.amount >= _amount, "CampaignFund: Refund amount exceeds contribution balance");

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
     * @dev Distributes campaign funds held by the contract to multiple recipients, applying tax.
     * Draws from the contract's total token balance. Does NOT affect individual contribution record amounts.
     * @param _recipients An array of addresses to send funds to.
     * @param _amounts An array of corresponding token amounts to send.
     */
    function distributeFunds(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner nonReentrant {
        require(_recipients.length == _amounts.length, "CampaignFund: Recipients/amounts length mismatch");
        require(_recipients.length > 0, "CampaignFund: Recipients array empty");

        uint256 totalAmountToDistribute = 0;        
        for (uint i = 0; i < _amounts.length; i++) {
            require(_amounts[i] > 0, "CampaignFund: Distribution amount must be positive");
            require(_recipients[i] != address(0), "CampaignFund: Recipient cannot be zero address");
            totalAmountToDistribute = totalAmountToDistribute + _amounts[i];
        }        
        // Calculate tax
        uint256 taxAmount = 0;
        if (taxAddress != address(0) && taxPercentageBps > 0) {
            taxAmount = (totalAmountToDistribute * taxPercentageBps) / MAX_TAX_BPS;
        }

        uint256 totalOutflow = totalAmountToDistribute + taxAmount;

        // Check total balance *before* any transfers
        require(token.balanceOf(address(this)) >= totalOutflow, "CampaignFund: Insufficient balance for distribution + tax");

        // Transfer tax first (if applicable)
        if (taxAmount > 0) {
             _safeTransfer(taxAddress, taxAmount);
        }

        // Distribute to recipients
        for (uint i = 0; i < _recipients.length; i++) {
             _safeTransfer(_recipients[i], _amounts[i]);
        }

        emit Distributed(_recipients, _amounts, taxAmount);
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
        require(_newTaxPercentageBps <= MAX_TAX_BPS, "CampaignFund: Tax percentage exceeds maximum");
        taxPercentageBps = _newTaxPercentageBps;
        emit TaxPercentageSet(_newTaxPercentageBps);
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
        require(success, "CampaignFund: ERC20 transfer failed");
    }

     /**
     * @dev Internal function for safely transferring tokens to this contract.
     */
    function _safeTransferFrom(address _from, address _to, uint256 _amount) internal {
        bool success = token.transferFrom(_from, _to, _amount);
        require(success, "CampaignFund: ERC20 transferFrom failed. Check allowance.");
    }
}