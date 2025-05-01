## Write2Earn Contracts

```
Blog Token

https://pharosscan.xyz/address/0xb4b741e3d1239b6dd7b7131c60c48a1029efb4aa


Factory Campaign

https://pharosscan.xyz/address/0xae03063fe750ebbe171754445d82a73dfe15957a


Campaign Manager

https://pharosscan.xyz/address/0x0efa9e28cbea1e15c530016140a0ef8110ab81bc

```

### Commands

Create Campaign

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x0efa9e28cbea1e15c530016140a0ef8110ab81bc 'createCampaign(string,uint256,uint256,uint256)' <CAMPAIGN NAME> <START TIMESTAMP> <END TIMESTAMP> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>
```

Campaign Owner Deposit Reward

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0xb4b741e3d1239b6dd7b7131c60c48a1029efb4aa 'approve(address,uint256)' <CAMPAIGN ADDRESS> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>

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
