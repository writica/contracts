## Write2Earn Contracts

```
Blog Token

https://pharosscan.xyz/address/0x79b4f48276bdd90098b81d331287216ccff5ed69


Factory Campaign

https://pharosscan.xyz/address/0x613ee8e6467dfea27b59cfffbc174a9a47f72972


Campaign Manager

https://pharosscan.xyz/address/0x23a63231ae12a4e2e66b230dde0a235a47ebccb6

```

### Commands

Create Campaign

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x23a63231ae12a4e2e66b230dde0a235a47ebccb6 'createCampaign(string,uint256,uint256,uint256)' <CAMPAIGN NAME> <START TIMESTAMP> <END TIMESTAMP> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>
```

Campaign Owner Deposit Reward

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x79b4f48276bdd90098b81d331287216ccff5ed69 'approve(address,uint256)' <CAMPAIGN ADDRESS> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>

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
