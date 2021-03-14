// SPDX-License-Identifier: No License (None)
pragma solidity ^0.6.9;

import "./Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external returns (bool);
}

contract Airdrop is Ownable {

    address public signer;
    mapping (address => mapping(address => bool)) public isReceived; // token => user => isReceived
    mapping (address => uint256) public dropAmount; // token => amount of token to drop

    event SetSigner(address signer);
    event SetDropAmount(address token, uint256 dropAmount);

    function setSigner(address _address) external onlyOwner returns(bool) {
        signer = _address;
        emit SetSigner(_address);
        return true;
    }

    function setDropAmount(address _token, uint256 _dropAmount) external onlyOwner returns(bool) {
        dropAmount[_token] = _dropAmount;
        emit SetDropAmount(_token, _dropAmount);
        return true;
    }    

    function faucet(address token, bytes32 r, bytes32 s, uint8 v) external returns(bool){
        require(signer == ecrecover(keccak256(abi.encodePacked(token, msg.sender, dropAmount[token])), v, r, s), "ECDSA signature is not valid.");
        require(!isReceived[token][msg.sender], "Tokens already received");
        isReceived[token][msg.sender] == true;
        IERC20(token).mint(msg.sender, dropAmount[token]);
        return true;
    }

    function airdrop(address token, uint256 amount, address[] calldata recipients) external onlyOwner returns(bool) {
        for (uint i = 0; i < recipients.length; i++) {
            IERC20(token).transfer(recipients[i], amount);
        }
        return true;
    }

    function airdrop2(address token, uint256[] calldata amounts, address[] calldata recipients) external onlyOwner returns(bool) {
        require(amounts.length == recipients.length);
        for (uint i = 0; i < recipients.length; i++) {
            IERC20(token).transfer(recipients[i], amounts[i]);
        }
        return true;
    }
}