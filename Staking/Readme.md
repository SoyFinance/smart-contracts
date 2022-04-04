## Soy Staking

User can stake SOY tokens if staking ends before 2 October 2022 00:00:00 UTC

Multiplier from 0.5 to 1 with step 0.1 for staking rounds from 1 to 6 accordingly.

## Deployed on main net

Soy Staking [0xeB4511C90F9387De8F8945ABD8C803d5cB275509](https://explorer.callisto.network/address/0xeB4511C90F9387De8F8945ABD8C803d5cB275509/read-contract)

## Deployed test version on testnet

Soy Staking: [0x4E35A7060a499595a2337bc6A5ba6Ce8914e5F0A](https://testnet-explorer.callisto.network/address/0x4E35A7060a499595a2337bc6A5ba6Ce8914e5F0A/contracts)

Test SOY token: [0x5331B7E9f950612Ae445eF4C7178649a7E521Aa8](https://testnet-explorer.callisto.network/address/0x5331B7E9f950612Ae445eF4C7178649a7E521Aa8/contracts)

Global farm: [0xD0c75B709659FB2942dd8879535b356ba870bA8c](https://testnet-explorer.callisto.network/address/0xD0c75B709659FB2942dd8879535b356ba870bA8c/contracts)



## Stake

Transfer SOY tokens to staking contract using function `function transfer(address to, uint value, bytes memory data) external returns (bool success);`

Where: `bytes memory data` should contain ABI encoded `UINT` number of rounds.

`var data = web3.eth.abi.encodeParameter('uint256', numberOfRounds);`

## Unstake

User will receive staking amount + reward if call function [withdraw_stake()](https://github.com/SoyFinance/smart-contracts/blob/0cedb96821be647efb3c24dce3a4470d9067929d/Staking/SoyStaking.sol#L242)

## Claim reward

To claim reward only user have to call function function [claim()](https://github.com/SoyFinance/smart-contracts/blob/0cedb96821be647efb3c24dce3a4470d9067929d/Staking/SoyStaking.sol#L268)
