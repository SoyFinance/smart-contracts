// SPDX-License-Identifier: No License (None)

pragma solidity ^0.8.0;

// A simple contract that helps to understand what _data should be attached to a token transaction
// in order to make it call specific values amountIn, amountOutMin, path, to, deadline
// in the SoyFinance exchange contract.

// Deployed at 0x4329609a3024894d335670E3f758C380970749EB address on Callisto Mainnet (chainId = 820)

// You can simply fill args for the `get_erc223_calldata()` function in the deployed contract
// then take whatever it returns and assign to `_data` arg of the `transfer(address, uint256, bytes calldata)` function of ERC223 token
// in order to make it call this exactly `swapExactERC223ForTokens()` with given args upon being handled inside of `tokenReceived` fallback
// at the SouFinanceRouter contract.

contract ERC223CallDataHelper {
    function swapExactERC223ForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        
    }
    
    function get_erc223_calldata(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline) public view returns(bytes memory)
    {
        bytes memory _calldata = abi.encodeWithSignature("swapExactERC223ForTokens(uint256,uint256,address[],address,uint256)", amountIn, amountOutMin, path, to, deadline);
        return _calldata;
    }
}
