## Write2Earn Contracts

```
Blog Token

https://pharosscan.xyz/address/0xa156eEBF06FAC2F9DD7F9748f3f57de8C4bF6D1B


Factory Campaign

https://pharosscan.xyz/address/0x12EF71cee002363Fbd20F0cf4E3b289A2db179Ad


Campaign Manager

https://pharosscan.xyz/address/0x94464BcbFb7133c1e13f499Ad3De7AdE3CcCC749

```

### Commands

Add Campaign Owner

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x94464BcbFb7133c1e13f499Ad3De7AdE3CcCC749 'addCampaignOwner(address)' <CAMPAIGN_OWNER_ADDR> --private-key <DEPLOYER_PRIV_KEY>
```

Create Campaign

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0x94464BcbFb7133c1e13f499Ad3De7AdE3CcCC749 'createCampaign(string,uint256,uint256,uint256)' <CAMPAIGN NAME> <START TIMESTAMP> <END TIMESTAMP> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>
```

Campaign Owner Deposit Reward

```
cast send --rpc-url https://devnet.dplabs-internal.com/ 0xa156eEBF06FAC2F9DD7F9748f3f57de8C4bF6D1B 'approve(address,uint256)' <CAMPAIGN ADDRESS> <REWARD AMOUNT> --private-key <CAMPAIGN_OWNER_PRIV_KEY>

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
