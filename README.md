## Write2Earn Contracts

```
Blog Token

https://pharosscan.xyz/address/0x0e3e31c813b23cee22e1c1643ab974c8e2cc5769


Factory Campaign

https://pharosscan.xyz/address/0x1dbef158d3d238fdb8d1cd1f3648170e20bf5655


Campaign Manager

https://pharosscan.xyz/address/0x20d39d65bf09af1703417fedb2b69f1de9325b4e

```

### Commands

Add Campaign Owner

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x1dbef158d3d238fdb8d1cd1f3648170e20bf5655 'addCampaignOwner(address)' <CAMPAIGN_OWNER_ADDR> --private-key <DEPLOYER_PRIV_KEY>
```

Create Campaign

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x1dbef158d3d238fdb8d1cd1f3648170e20bf5655 'createCampaign(string,uint256,uint256,uint256)' <CAMPAIGN NAME> <START TIMESTAMP> <END TIMESTAMP> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>
```

Campaign Owner Deposit Reward

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x0e3e31c813b23cee22e1c1643ab974c8e2cc5769 'approve(address,uint256)' <CAMPAIGN ADDRESS> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>

cast send --rpc-url https://devnet.dplabs-internal.com/ <CAMPAIGN ADDRESS> 'depositReward()' --private-key <CAMPAIGN_OWNER_PRIV_KEY>
```

Add Contributor

```
cast send --rpc-url https://devnet.dplabs-internal.com/ <CAMPAIGN ADDRESS> 'addContributors(address[],uint256[])' <CONTRIBUTOR ADDRESS> <CONTRIBUTOR SCORES> --private-key <CAMPAIGN_MANAGER_PRIV_KEY>
```

Contributor Withdraw Reward

```
cast send --rpc-url https://devnet.dplabs-internal.com/ <CAMPAIGN ADDRESS> 'withdraw()' --private-key <CONTRIBUTOR_PRIV_KEY>
```
