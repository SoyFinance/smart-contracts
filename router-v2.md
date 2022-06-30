# Router v2

{% hint style="warning" %}
SOY Finance is based on Uniswap v2. Read the [Uniswap v2 documentation](https://docs.uniswap.org/protocol/V2/introduction).\
For more in-depth information on the core contract logic, read the [Uniswap v2 Core whitepaper](https://github.com/Uniswap/docs/blob/main/static/whitepaper.pdf).
{% endhint %}

## Contract info

**Contract name:** SoyFinanceRouter\


View [SoyFinanceRouter.sol on GitHub](https://github.com/SoyFinance/smart-contracts/blob/main/SoyFinanceRouter.sol).


View the **SoyFinance Router v2** contract on:
- Callisto Network [0xeB5B468fAacC6bBdc14c4aacF0eec38ABCCC13e7](https://explorer.callisto.network/address/0xeB5B468fAacC6bBdc14c4aacF0eec38ABCCC13e7).
- BitTorrent chain (BTTC) [0x8cb2e43e5aeb329de592f7e49b6c454649b61929](https://bttcscan.com/address/0x8Cb2e43e5AEB329de592F7e49B6c454649b61929#code)
- Binance Smart Chain (BSC) [0x8c5Bba04B2f5CCCe0f8F951D2DE9616BE190070D](https://bscscan.com/address/0x8c5Bba04B2f5CCCe0f8F951D2DE9616BE190070D#code)
- Ethereum Classic (ETC) [0x8c5Bba04B2f5CCCe0f8F951D2DE9616BE190070D](https://blockscout.com/etc/mainnet/address/0x8c5Bba04B2f5CCCe0f8F951D2DE9616BE190070D/contracts)

## Read functions

### WCLO

`function WCLO() external pure returns (address);`

Returns the canonical address for [Callisto: WCLO token](https://explorer.callisto.network/address/0xF5AD6F6EDeC824C7fD54A66d241a227F6503aD3a) (WCLO being a vestige from Callisto network origins).

### factory

`function factory() external pure returns (address);`

Returns the canonical address for [SoyFinanceFactory](https://explorer.callisto.network/address/0x9CC7C769eA3B37F1Af0Ad642A268b80dc80754c5).

{% hint style="warning" %}
For explanations of the following, view the [Uniswap v2 Internal Functions documentation](https://uniswap.org/docs/v2/smart-contracts/library/#internal-functions).
{% endhint %}

### getAmountOut

`function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut);`

### getAmountIn

`function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn);`

### getAmountsOut

`function getAmountsOut(uint amountIn, address[] memory path) internal view returns (uint[] memory amounts);`

### getAmountsIn

`function getAmountsIn(uint amountOut, address[] memory path) internal view returns (uint[] memory amounts);`

### quote

`function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB);`

## Write functions

### addLiquidity

```
function addLiquidity(
  address tokenA,
  address tokenB,
  uint amountADesired,
  uint amountBDesired,
  uint amountAMin,
  uint amountBMin,
  address to,
  uint deadline
) external returns (uint amountA, uint amountB, uint liquidity);
```

Adds liquidity to a BEP20⇄BEP20 pool.

| Name           | Type      |                                                                   |
| -------------- | --------- | ----------------------------------------------------------------- |
| tokenA         | `address` | The contract address of one token from your liquidity pair.       |
| tokenB         | `address` | The contract address of the other token from your liquidity pair. |
| amountADesired | `uint`    | The amount of tokenA you'd like to provide as liquidity.          |
| amountBDesired | `uint`    | The amount of tokenA you'd like to provide as liquidity.          |
| amountAMin     | `uint`    | The minimum amount of tokenA to provide (slippage impact).        |
| amountBMin     | `uint`    | The minimum amount of tokenB to provide (slippage impact).        |
| to             | `address` | Address of LP Token recipient.                                    |
| deadline       | `uint`    | Unix timestamp deadline by which the transaction must confirm.    |

### addLiquidityCLO

```
function addLiquidityCLO(
  address token,
  uint amountTokenDesired,
  uint amountTokenMin,
  uint amountCLOMin,
  address to,
  uint deadline
) external payable returns (uint amountToken, uint amountCLO, uint liquidity);
```

Adds liquidity to a BEP20⇄WCLO pool.

| Name               | Type      |                                                                |
| ------------------ | --------- | -------------------------------------------------------------- |
| addLiquidityCLO    | `uint`    | The payable amount in CLO.                                     |
| token              | `address` | The contract address of the token to add liquidity.            |
| amountTokenDesired | `uint`    | The amount of the token you'd like to provide as liquidity.    |
| amountTokenMin     | `uint`    | The minimum amount of the token to provide (slippage impact).  |
| amountCLOMin       | `uint`    | The minimum amount of CLO to provide (slippage impact).        |
| to                 | `address` | Address of LP Token recipient.                                 |
| deadline           | `uint`    | Unix timestamp deadline by which the transaction must confirm. |

### removeLiquidity

```
function removeLiquidity(
  address tokenA,
  address tokenB,
  uint liquidity,
  uint amountAMin,
  uint amountBMin,
  address to,
  uint deadline
) external returns (uint amountA, uint amountB);
```

Removes liquidity from a BEP20⇄BEP20 pool.

| Name       | Type      |                                                                   |
| ---------- | --------- | ----------------------------------------------------------------- |
| tokenA     | `address` | The contract address of one token from your liquidity pair.       |
| tokenB     | `address` | The contract address of the other token from your liquidity pair. |
| liquidity  | `uint`    | The amount of LP Tokens to remove.                                |
| amountAMin | `uint`    | The minimum amount of tokenA to remove (slippage impact).         |
| amountBMin | `uint`    | The minimum amount of tokenB to remove (slippage impact).         |
| to         | `address` | Address of LP Token recipient.                                    |
| deadline   | `uint`    | Unix timestamp deadline by which the transaction must confirm.    |

### removeLiquidityCLO

```
function removeLiquidityCLO(
  address token,
  uint liquidity,
  uint amountTokenMin,
  uint amountCLOMin,
  address to,
  uint deadline
) external returns (uint amountToken, uint amountCLO);
```

Removes liquidity from a BEP20⇄WCLO pool.

| Name           | Type      |                                                                |
| -------------- | --------- | -------------------------------------------------------------- |
| token          | `address` | The contract address of the token to remove liquidity.         |
| liquidity      | `uint`    | The amount of LP Tokens to remove.                             |
| amountTokenMin | `uint`    | The minimum amount of the token to remove (slippage impact).   |
| amountCLOMin   | `uint`    | The minimum amount of CLO to remove (slippage impact).         |
| to             | `address` | Address of LP Token recipient.                                 |
| deadline       | `uint`    | Unix timestamp deadline by which the transaction must confirm. |

### removeLiquidityCLOSupportingFeeOnTransferTokens

```
function removeLiquidityCLOSupportingFeeOnTransferTokens(
  address token,
  uint liquidity,
  uint amountTokenMin,
  uint amountCLOMin,
  address to,
  uint deadline
) external returns (uint amountCLO);
```

Removes liquidity from a BEP20⇄WCLO for tokens that take a fee on transfer.

| Name           | Type      |                                                                |
| -------------- | --------- | -------------------------------------------------------------- |
| token          | `address` | The contract address of the token to remove liquidity.         |
| liquidity      | `uint`    | The amount of LP Tokens to remove.                             |
| amountTokenMin | `uint`    | The minimum amount of the token to remove (slippage impact).   |
| amountCLOMin   | `uint`    | The minimum amount of CLO to remove (slippage impact).         |
| to             | `address` | Address of LP Token recipient.                                 |
| deadline       | `uint`    | Unix timestamp deadline by which the transaction must confirm. |

### removeLiquidityCLOWithPermit

```
function removeLiquidityCLOWithPermit(
  address token,
  uint liquidity,
  uint amountTokenMin,
  uint amountCLOMin,
  address to,
  uint deadline,
  bool approveMax, uint8 v, bytes32 r, bytes32 s
) external returns (uint amountToken, uint amountCLO);
```

Removes liquidity from a BEP20⇄WCLO and receives CLO, without pre-approval, via permit.

| Name           | Type      |                                                                                     |
| -------------- | --------- | ----------------------------------------------------------------------------------- |
| token          | `address` | The contract address of the token to remove liquidity.                              |
| liquidity      | `uint`    | The amount of LP Tokens to remove.                                                  |
| amountTokenMin | `uint`    | The minimum amount of the token to remove (slippage impact).                        |
| amountCLOMin   | `uint`    | The minimum amount of CLO to remove (slippage impact).                              |
| to             | `address` | Address of LP Token recipient.                                                      |
| deadline       | `uint`    | Unix timestamp deadline by which the transaction must confirm.                      |
| approveMax     | `bool`    | Whether or not the approval amount in the signature is for liquidity or `uint(-1)`. |
| v              | `uint8`   | The v component of the permit signature.                                            |
| r              | `bytes32` | The r component of the permit signature.                                            |
| s              | `bytes32` | The s component of the permit signature.                                            |

### removeLiquidityCLOWithPermitSupportingFeeOnTransferTokens

```
function removeLiquidityCLOWithPermitSupportingFeeOnTransferTokens(
  address token,
  uint liquidity,
  uint amountTokenMin,
  uint amountCLOMin,
  address to,
  uint deadline,
  bool approveMax, uint8 v, bytes32 r, bytes32 s
) external returns (uint amountCLO);
```

Removes liquidity from a BEP20⇄WCLO and receives CLO via permit for tokens that take a fee on transfer.

| Name           | Type      |                                                                                     |
| -------------- | --------- | ----------------------------------------------------------------------------------- |
| token          | `address` | The contract address of the token to remove liquidity.                              |
| liquidity      | `uint`    | The amount of LP Tokens to remove.                                                  |
| amountTokenMin | `uint`    | The minimum amount of the token to remove (slippage impact).                        |
| amountCLOMin   | `uint`    | The minimum amount of CLO to remove (slippage impact).                              |
| to             | `address` | Address of LP Token recipient.                                                      |
| deadline       | `uint`    | Unix timestamp deadline by which the transaction must confirm.                      |
| approveMax     | `bool`    | Whether or not the approval amount in the signature is for liquidity or `uint(-1)`. |
| v              | `uint8`   | The v component of the permit signature.                                            |
| r              | `bytes32` | The r component of the permit signature.                                            |
| s              | `bytes32` | The s component of the permit signature.                                            |

### removeLiquidityWithPermit

```
function removeLiquidityWithPermit(
  address tokenA,
  address tokenB,
  uint liquidity,
  uint amountAMin,
  uint amountBMin,
  address to,
  uint deadline,
  bool approveMax, uint8 v, bytes32 r, bytes32 s
) external returns (uint amountA, uint amountB);
```

Removes liquidity from a BEP20⇄BEP20, without pre-approval, via permit.

| Name           | Type      |                                                                                     |
| -------------- | --------- | ----------------------------------------------------------------------------------- |
| tokenA         | `address` | The contract address of one token from your liquidity pair.                         |
| tokenB         | `address` | The contract address of the other token from your liquidity pair.                   |
| liquidity      | `uint`    | The amount of LP Tokens to remove.                                                  |
| amountTokenMin | `uint`    | The minimum amount of the token to remove (slippage impact).                        |
| amountCLOMin   | `uint`    | The minimum amount of CLO to remove (slippage impact).                              |
| to             | `address` | Address of LP Token recipient.                                                      |
| deadline       | `uint`    | Unix timestamp deadline by which the transaction must confirm.                      |
| approveMax     | `bool`    | Whether or not the approval amount in the signature is for liquidity or `uint(-1)`. |
| v              | `uint8`   | The v component of the permit signature.                                            |
| r              | `bytes32` | The r component of the permit signature.                                            |
| s              | `bytes32` | The s component of the permit signature.                                            |

### swapCLOForExactTokens

```
function swapCLOForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
  external
  payable
  returns (uint[] memory amounts);
```

Receive an exact amount of output tokens for as little CLO as possible.

| Name                  | Type      |                                                                                                                                      |
| --------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| swapCLOForExactTokens | `uint`    | Payable CLO amount.                                                                                                                  |
| amountOut             | `uint`    | The amount tokens to receive.                                                                                                        |
| path (address\[])     | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                    | `address` | Address of recipient.                                                                                                                |
| deadline              | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapExactCLOForTokens

```
function swapExactCLOForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
  external
  payable
  returns (uint[] memory amounts);
```

Receive as many output tokens as possible for an exact amount of CLO.

| Name                  | Type      |                                                                                                                                      |
| --------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| swapExactCLOForTokens | `uint`    | Payable CLO amount.                                                                                                                  |
| amountOutMin          | `uint`    | The minimum amount tokens to receive.                                                                                                |
| path (address\[])     | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                    | `address` | Address of recipient.                                                                                                                |
| deadline              | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapExactCLOForTokensSupportingFeeOnTransferTokens

```
function swapExactCLOForTokensSupportingFeeOnTransferTokens(
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
) external payable;
```

Receive as many output tokens as possible for an exact amount of CLO. Supports tokens that take a fee on transfer.

| Name                                               | Type      |                                                                                                                                      |
| -------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| swapExactCLOForTokensSupportingFeeOnTransferTokens | `uint`    | Payable CLO amount.                                                                                                                  |
| amountOutMin                                       | `uint`    | The minimum amount tokens to receive.                                                                                                |
| path (address\[])                                  | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                                                 | `address` | Address of recipient.                                                                                                                |
| deadline                                           | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapExactTokensForCLO

```
function swapExactTokensForCLO(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
  external
  returns (uint[] memory amounts);
```

Receive as much CLO as possible for an exact amount of input tokens.

| Name              | Type      |                                                                                                                                      |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| amountIn          | `uint`    | Payable amount of input tokens.                                                                                                      |
| amountOutMin      | `uint`    | The minimum amount tokens to receive.                                                                                                |
| path (address\[]) | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                | `address` | Address of recipient.                                                                                                                |
| deadline          | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapExactTokensForCLOSupportingFeeOnTransferTokens

```
function swapExactTokensForCLOSupportingFeeOnTransferTokens(
  uint amountIn,
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
) external;
```

Receive as much CLO as possible for an exact amount of tokens. Supports tokens that take a fee on transfer.

| Name              | Type      |                                                                                                                                      |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| amountIn          | `uint`    | Payable amount of input tokens.                                                                                                      |
| amountOutMin      | `uint`    | The minimum amount tokens to receive.                                                                                                |
| path (address\[]) | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                | `address` | Address of recipient.                                                                                                                |
| deadline          | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapExactTokensForTokens

```
function swapExactTokensForTokens(
  uint amountIn,
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
) external returns (uint[] memory amounts);
```

Receive as many output tokens as possible for an exact amount of input tokens.

| Name              | Type      |                                                                                                                                      |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| amountIn          | `uint`    | Payable amount of input tokens.                                                                                                      |
| amountOutMin      | `uint`    | The minimum amount tokens to receive.                                                                                                |
| path (address\[]) | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                | `address` | Address of recipient.                                                                                                                |
| deadline          | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapExactTokensForTokensSupportingFeeOnTransferTokens

```
function swapExactTokensForTokensSupportingFeeOnTransferTokens(
  uint amountIn,
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
) external;
```

Receive as many output tokens as possible for an exact amount of input tokens. Supports tokens that take a fee on transfer.

| Name              | Type      |                                                                                                                                      |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| amountIn          | `uint`    | Payable amount of input tokens.                                                                                                      |
| amountOutMin      | `uint`    | The minimum amount tokens to receive.                                                                                                |
| path (address\[]) | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                | `address` | Address of recipient.                                                                                                                |
| deadline          | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapTokensForExactCLO

```
function swapTokensForExactCLO(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
  external
  returns (uint[] memory amounts);
```

Receive an exact amount of CLO for as few input tokens as possible.

| Name              | Type      |                                                                                                                                      |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| amountOut         | `uint`    | Payable amount of input tokens.                                                                                                      |
| amountInMax       | `uint`    | The minimum amount tokens to input.                                                                                                  |
| path (address\[]) | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                | `address` | Address of recipient.                                                                                                                |
| deadline          | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

### swapTokensForExactTokens

```
function swapTokensForExactTokens(
  uint amountOut,
  uint amountInMax,
  address[] calldata path,
  address to,
  uint deadline
) external returns (uint[] memory amounts);
```

Receive an exact amount of output tokens for as few input tokens as possible.

| Name              | Type      |                                                                                                                                      |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| amountOut         | `uint`    | Payable amount of input tokens.                                                                                                      |
| amountInMax       | `uint`    | The minimum amount tokens to input.                                                                                                  |
| path (address\[]) | `address` | An array of token addresses. `path.length` must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity. |
| to                | `address` | Address of recipient.                                                                                                                |
| deadline          | `uint`    | Unix timestamp deadline by which the transaction must confirm.                                                                       |

## Interface

```
import '@uniswap/v2-core/contracts/interfaces/ISoyFinanceRouter.sol';
```

```
pragma solidity >=0.6.2;

interface ISoyFinanceRouter01 {
    function factory() external pure returns (address);
    function WCLO() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityCLO(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountCLOMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountCLO, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityCLO(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountCLOMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountCLO);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityCLOWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountCLOMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountCLO);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactCLOForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactCLO(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForCLO(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapCLOForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// File: contracts\interfaces\ISoyFinanceRouter02.sol

pragma solidity >=0.6.2;

interface ISoyFinanceRouter02 is ISoyFinanceRouter01 {
    function removeLiquidityCLOSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountCLOMin,
        address to,
        uint deadline
    ) external returns (uint amountCLO);
    function removeLiquidityCLOWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountCLOMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountCLO);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactCLOForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForCLOSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}
```
