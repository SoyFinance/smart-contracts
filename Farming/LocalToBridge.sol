// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;

interface IBridge{
    function depositTokens(
        address receiver,   // address of token receiver on destination chain
        address token,      // token that user send (if token address < 32, then send native coin)
        uint256 value,      // tokens value
        uint256 toChainId   // destination chain Id where will be claimed tokens
    ) external;
}

interface IERC20 {
    // initialize cloned token just for BEP20TokenCloned
    function balanceOf(address account) external view returns (uint256);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ISimplifiedGlobalFarm {
    function mintFarmingReward(address _localFarm) external;
    function getAllocationX1000(address _farm) external view returns (uint256);
    function getRewardPerSecond() external view returns (uint256);
    function rewardMintingAvailable(address _farm) external view returns (bool);
    function farmExists(address _farmAddress) external view returns (bool);
    function owner() external view returns (address);
}


contract LocalToBridge {

    address public soy = address(0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65);
    address public bridge = address(0x9a1fc8C0369D49f3040bF49c1490E7006657ea56);
    address public globalFarm = address(0x64Fa36ACD0d13472FD786B03afC9C52aD5FCf023);
    address public foreignGlobalFarm;
    uint256 public foreignGlobalFarmChainId;
    uint256 public lastRewardTimestamp;  // Last block number that SOY distribution occurs.
    
    event RewardAdded(uint256 reward);

    constructor (address _foreignGlobalFarm, uint256 _foreignGlobalFarmChainId) {
        foreignGlobalFarm = _foreignGlobalFarm;
        foreignGlobalFarmChainId = _foreignGlobalFarmChainId;
        IERC20(soy).approve(bridge, type(uint256).max);
    }

    function tokenReceived(address _from, uint256 _amount, bytes memory _data) external
    {
        require(msg.sender == soy && _from == globalFarm, "sender is not allowed");
    }

    function notifyRewardAmount(uint256 reward) external
    {
        require (msg.sender == globalFarm, "Only globalFarm");
        IBridge(bridge).depositTokens(foreignGlobalFarm, soy, reward, foreignGlobalFarmChainId);
        emit RewardAdded(reward);
    }

    function claim() external {
        require(ISimplifiedGlobalFarm(globalFarm).rewardMintingAvailable(address(this)), "Reward not available");
        ISimplifiedGlobalFarm(globalFarm).mintFarmingReward(address(this));
        lastRewardTimestamp = block.timestamp;
    }
}