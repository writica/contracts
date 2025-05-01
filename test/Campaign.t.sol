// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Campaign} from "../src/Campaign.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1 million tokens to deployer
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract CampaignTest is Test {
    Campaign public campaign;
    MockToken public token;

    address public owner;
    address public campaignOwner;
    address public campaignManager;
    address public contributor01;
    address public contributor02;
    address public contributor03;
    address public taxCollector;

    uint256 public constant INITIAL_TOKEN_AMOUNT = 10000 * 10 ** 18; // 10,000 tokens
    uint256 public constant TAX_PERCENTAGE = 500; // 5%

    event RewardDeposited(uint256 amount);
    event ContributionIncreased(
        uint256 indexed contributionId,
        uint256 additionalAmount,
        uint256 newTotalAmount
    );
    event ContributionRefunded(
        uint256 indexed contributionId,
        address indexed contributor,
        uint256 refundedAmount,
        uint256 remainingAmount
    );
    event ContributionClosed(uint256 indexed contributionId);
    event Distributed(
        address[] recipients,
        uint256[] amounts,
        uint256 taxAmount
    );
    event TaxAddressSet(address indexed newTaxAddress);
    event TaxPercentageSet(uint256 newTaxPercentageBps);
    event CampaignNameUpdated(string newName);
    event ContributorAdded(address[] contributors, uint256[] scores);
    event SingleContributorAdded(address contributor, uint256 score);
    event RewardWithdrawn(address contributor, uint256 amount);

    function setUp() public {
        // Set up accounts
        owner = address(this);
        campaignOwner = makeAddr("campaignOwner");
        campaignManager = makeAddr("campaignManager");
        contributor01 = makeAddr("contributor01");
        contributor02 = makeAddr("contributor02");
        contributor03 = makeAddr("contributor03");
        taxCollector = makeAddr("taxCollector");

        // Deploy token
        token = new MockToken();
        token.transfer(campaignOwner, 1000 * 10 ** 18);

        // Deploy campaign
        campaign = new Campaign(
            "Test Campaign",
            block.timestamp + 1 days,
            block.timestamp + 30 days,
            500 * 10 ** 18,
            address(token),
            taxCollector,
            TAX_PERCENTAGE,
            campaignOwner,
            campaignManager
        );
    }

    function test_Deployment() public view {
        assertEq(campaign.name(), "Test Campaign");
        assertEq(address(campaign.rewardAddress()), address(token));
        assertEq(campaign.taxAddress(), taxCollector);
        assertEq(campaign.taxPercentageBps(), TAX_PERCENTAGE);
    }

    function test_CreateDeposit() public {
        // Approve tokens
        vm.startPrank(campaignOwner);
        token.approve(address(campaign), 500 * 10 ** 18);

        vm.warp(block.timestamp + 2 days);

        // Create contribution
        vm.expectEmit(true, true, false, false);
        emit RewardDeposited(475 * 10 ** 18);
        campaign.depositReward();

        assertEq(campaign.totalReward(), 475 * 10 ** 18);

        vm.stopPrank();
    }

    function test_AddContributor() public {
        vm.startPrank(campaignOwner);
        token.approve(address(campaign), 500 * 10 ** 18);

        vm.warp(block.timestamp + 2 days);
        campaign.depositReward();

        address[] memory contributors = new address[](2);
        uint256[] memory scores = new uint256[](2);
        contributors[0] = contributor01;
        contributors[1] = contributor02;
        scores[0] = 10;
        scores[1] = 20;

        // Add to contribution
        vm.expectEmit(true, false, false, false);
        emit ContributorAdded(contributors, scores);
        campaign.addContributors(contributors, scores);

        // Verify updated amount
        uint256 amount = campaign.scores(contributors[0]);
        uint256 amount2 = campaign.scores(contributors[1]);
        assertEq(amount, scores[0]);
        assertEq(amount2, scores[1]);

        // Add singe score to contribution
        vm.expectEmit(true, false, false, false);
        emit SingleContributorAdded(contributor03, 30);
        campaign.addContributor(contributor03, 30);

        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(campaignOwner);
        token.approve(address(campaign), 500 * 10 ** 18);

        vm.warp(block.timestamp + 2 days);
        campaign.depositReward();

        address[] memory contributors = new address[](2);
        uint256[] memory scores = new uint256[](2);
        contributors[0] = contributor01;
        contributors[1] = contributor02;
        scores[0] = 10;
        scores[1] = 20;

        campaign.addContributors(contributors, scores);

        vm.stopPrank();

        assertEq(token.balanceOf(contributor01), 0);

        vm.startPrank(contributor01);

        uint256 share = ((475 * 10 ** 18) * 10) / uint256(30);

        vm.expectEmit(true, false, false, false);
        emit RewardWithdrawn(contributors[0], share);
        campaign.withdraw();

        // Verify updated amount

        vm.stopPrank();

        // Verify balances
        assertEq(token.balanceOf(contributor01), share);
    }

    function test_UpdateCampaignName() public {
        vm.startPrank(campaignOwner);

        string memory newName = "Updated Campaign";
        vm.expectEmit(true, false, false, true);
        emit CampaignNameUpdated(newName);
        campaign.updateCampaignName(newName);

        vm.stopPrank();

        assertEq(campaign.name(), newName);
    }
}
