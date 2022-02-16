## Soy Staking

User can stake SOY tokens if staking ends before 1 September 2022 12:00:00 UTC

Multiplier from 0.5 to 1 with step 0.1 for staking rounds from 1 to 6 accordingly.


## Deployed test version on mainnet

test version: 0x5AB8aCe9DcD22D2d16C0579C6934E8c097E6b0b3 https://explorer.callisto.network/address/0x5AB8aCe9DcD22D2d16C0579C6934E8c097E6b0b3/contracts

use test SOY and Global farm from here:
- https://github.com/SoyFinance/smart-contracts/tree/main/Farming#testsoy223-token

`address public constant SOY = 0xC8227f810FB2F4FacBf9D3CAbca21e47f51d87a3;`


- https://github.com/SoyFinance/smart-contracts/tree/main/Farming#test-global-farm-contract-3-minutes

`address public constant globalFarm = 0xE8B2Fee5D18ec30f5625a5f7F1f06E5df17E1774;`

## Stake

Transfer SOY tokens to staking contract using function `function transfer(address to, uint value, bytes memory data) external returns (bool success);`

Where: `bytes memory data` should contain ABI encoded `UINT` number of rounds.

`var data = web3.eth.abi.encodeParameter('uint256', numberOfRounds);`

## Unstake

User will receive staking amount + reward if call function [withdraw_stake()](https://github.com/SoyFinance/smart-contracts/blob/0cedb96821be647efb3c24dce3a4470d9067929d/Staking/SoyStaking.sol#L242)

## Claim reward

To claim reward only user have to call function function [claim()](https://github.com/SoyFinance/smart-contracts/blob/0cedb96821be647efb3c24dce3a4470d9067929d/Staking/SoyStaking.sol#L268)