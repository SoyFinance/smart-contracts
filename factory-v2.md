# Factory v2

{% hint style="warning" %}
SOY Finance is based on Uniswap v2. Read the [Uniswap v2 documentation](https://uniswap.org/docs/v2/).  
For more in-depth information on the core contract logic, read the [Uniswap v2 Core whitepaper](https://uniswap.org/whitepaper.pdf).
{% endhint %}

## Contract info

**Contract name:** SoyFinanceFactory  

View [SoyFinanceFactory.sol on GitHub](https://github.com/SoyFinance/smart-contracts/blob/main/SoyFinanceFactory.sol).

View the **SoyFinanceFactory** contract on:
- Callisto Network [0x9CC7C769eA3B37F1Af0Ad642A268b80dc80754c5](https://explorer.callisto.network/address/0x9CC7C769eA3B37F1Af0Ad642A268b80dc80754c5).
- BitTorrent chain (BTTC) [0xbf6c50889d3a620eb42c0f188b65ade90de958c4](https://bttcscan.com/address/0xbf6c50889d3a620eb42c0f188b65ade90de958c4#code)
- Binance Smart Chain (BSC) [0x23675f1Ac7cce101Aff647B96d7201EfCf66E4b0](https://bscscan.com/address/0x23675f1Ac7cce101Aff647B96d7201EfCf66E4b0#code)
- Ethereum Classic (ETC)) [0x23675f1Ac7cce101Aff647B96d7201EfCf66E4b0](https://blockscout.com/etc/mainnet/address/0x23675f1Ac7cce101Aff647B96d7201EfCf66E4b0/contracts)

## Read functions

### getPair

`function getPair(address tokenA, address tokenB) external view returns (address pair);`

Address for `tokenA` and address for `tokenB` return address of pair contract \(where one exists\).

`tokenA` and `tokenB` order is interchangeable.

Returns `0x0000000000000000000000000000000000000000` as address where no pair exists.

### allPairs

`function allPairs(uint) external view returns (address pair);`

Returns the address of the `n`th pair \(`0`-indexed\) created through the Factory contract.

Returns `0x0000000000000000000000000000000000000000` where pair has not yet been created.

Begins at `0` for first created pair.

### allPairsLength

`function allPairsLength() external view returns (uint);`

Displays the current number of pairs created through the Factory contract as an integer.

### feeTo

`function feeTo() external view returns (address);`

The address to where non-LP-holder fees are sent.

### feeToSetter

`function feeToSetter() external view returns (address);`

The address with permission to set the feeTo address.

## Write functions

### createPair

function createPair\(address tokenA, address tokenB\) external returns \(address pair\);

Creates a pair for `tokenA` and `tokenB` where a pair doesn't already exist.

`tokenA` and `tokenB` order is interchangeable.

Emits `PairCreated` \(see Events\).

### setFeeTo

Sets address for `feeTo`.

### setFeeToSetter

Sets address for permission to adjust `feeTo`.

## Events

### PairCreated

`event PairCreated(address indexed token0, address indexed token1, address pair, uint);`

Emitted whenever a `createPair` creates a new pair.

`token0` will appear before `token1` in sort order.

The final `uint` log value will be `1` for the first pair created, `2` for the second, etc.

## Interface

```text
import '@uniswap/v2-core/contracts/interfaces/ISoyFinanceFactory.sol';
```

```text
pragma solidity =0.5.16;


interface ISoyFinanceFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
```

