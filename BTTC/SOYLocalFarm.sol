// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;


abstract contract IERC223 {
    /**
     * @dev Returns the balance of the `who` address.
     */
    function balanceOf(address who) public virtual view returns (uint);
        
    /**
     * @dev Transfers `value` tokens from `msg.sender` to `to` address
     * and returns `true` on success.
     */
    function transfer(address to, uint value) public virtual returns (bool success);
        
}


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the `nonReentrant` modifier
 * available, which can be aplied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

abstract contract RewardsRecipient {
    address public globalFarm;

    function notifyRewardAmount(uint256 reward) external virtual;

    modifier onlyGlobalFarm() {
        require(msg.sender == globalFarm, "Caller is not global Farm contract");
        _;
    }
}


interface ISimplifiedGlobalFarm {
    function mintFarmingReward(address _localFarm) external;
    function getAllocationX1000(address _farm) external view returns (uint256);
    function getRewardPerSecond() external view returns (uint256);
    function rewardMintingAvailable(address _farm) external view returns (bool);
    function farmExists(address _farmAddress) external view returns (bool);
    function owner() external view returns (address);
}


contract SOYLocalFarm is ReentrancyGuard, RewardsRecipient
{

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    
    
    /* ========== VARIABLES ========== */

    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }
    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;
    
    uint256 public limitAmount; // Prevents accumulatedRewardPerShare from overflowing.
    
    IERC223 public rewardsToken;
    IERC223 public lpToken;
    
    uint256 public lastRewardTimestamp;  // Last block number that SOY distribution occurs.
    uint256 public accumulatedRewardPerShare; // Accumulated SOY per share, times 1e18. See below.

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Not Owner");
        _;
    }

    // Local Farm owner is an owner of Global Farm contract
    function owner() public view returns(address) {
        return ISimplifiedGlobalFarm(globalFarm).owner();
    }

    function initialize(
        address _rewardsToken,      // SOY token
        address _lpToken            // LP token that will be staked in this Local Farm
    ) 
        external
    {
        require(globalFarm == address(0), "Already initialized");
        rewardsToken        = IERC223(_rewardsToken);
        lpToken             = IERC223(_lpToken);
        globalFarm          = msg.sender; // GlobalFarm contract
        limitAmount = 1e40;
    }
    
    bool active = false;
    
    modifier onlyActive {
        require(active, "The farm is not enabled by owner!");
        _;
    }
    
    function setActive(bool _status) external onlyOwner
    {
        active = _status;
    }
    
    /* ========== ERC223 transaction handlers ====== */
    
    // Analogue of deposit() function.
    function tokenReceived(address _from, uint256 _amount, bytes memory _data) public nonReentrant onlyActive
    {
        require(msg.sender == address(lpToken), "Trying to deposit wrong token");
        require(userInfo[_from].amount + _amount <= limitAmount, 'exceed the top');

        update();
        if (userInfo[_from].amount > 0) {
            uint256 pending = userInfo[_from].amount * accumulatedRewardPerShare / 1e18 - userInfo[_from].rewardDebt;
            if(pending > 0) {
                rewardsToken.transfer(address(_from), pending);
            }
        }
        if(_amount > 0) {
            userInfo[_from].amount += _amount;
        }
        userInfo[_from].rewardDebt = userInfo[_from].amount * accumulatedRewardPerShare / 1e18;
        
        emit Staked(_from, _amount);
    }
    
    function notifyRewardAmount(uint256 reward) external override
    {
        emit RewardAdded(reward);
    }
    
    function getRewardPerSecond() public view returns (uint256)
    {
        return ISimplifiedGlobalFarm(globalFarm).getRewardPerSecond();
    }
    
    function getAllocationX1000() public view returns (uint256)
    {
        return ISimplifiedGlobalFarm(globalFarm).getAllocationX1000(address(this));
    }
    
    /* ========== Farm Functions ====== */

    // View function to see pending Reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accumulatedRewardPerShare = accumulatedRewardPerShare;
        uint256 lpSupply = lpToken.balanceOf(address(this));
        if (block.timestamp > lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = block.timestamp - lastRewardTimestamp;
            uint256 _reward = multiplier * getRewardPerSecond() * getAllocationX1000() / 1000;
            _accumulatedRewardPerShare = accumulatedRewardPerShare + (_reward * 1e18 / lpSupply);
        }
        return user.amount * _accumulatedRewardPerShare / 1e18 - user.rewardDebt;
    }
    
    

    // Update reward variables of this Local Farm to be up-to-date.
    function update() public reward_request {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = lpToken.balanceOf(address(this));
       
        if (lpSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp - lastRewardTimestamp;
        
        // This silently calculates "assumed" reward!
        // This function does not take contract's actual balance into account
        // Global Farm and `reward_request` modifier are responsible for keeping this contract
        // stocked with funds to pay actual rewards.
        
        uint256 _reward = multiplier * getRewardPerSecond() * getAllocationX1000() / 1000;
        accumulatedRewardPerShare = accumulatedRewardPerShare + (_reward * 1e18 / lpSupply);
        lastRewardTimestamp = block.timestamp;
    }
    
    

    // Withdraw tokens from STAKING.
    function withdraw(uint256 _amount) public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        
        update();
        uint256 pending = user.amount * accumulatedRewardPerShare / 1e18 - user.rewardDebt;
        if(pending > 0) {
            rewardsToken.transfer(address(msg.sender), pending);
        }
        if(_amount > 0) {
            user.amount = user.amount - _amount;
            lpToken.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount * accumulatedRewardPerShare / 1e18;

        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        lpToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }
    
    // Special function that allows owner to withdraw remaining unclaimed tokens of inactive farms
    function withdrawInactiveReward() public onlyOwner
    {
        require(!ISimplifiedGlobalFarm(globalFarm).farmExists(address(this)), "Farm must not be active");
        
        rewardsToken.transfer(msg.sender, rewardsToken.balanceOf(address(this)));
    }

/*
    // Withdraw reward. EMERGENCY ONLY.
    function emergencyRewardWithdraw(uint256 _amount) public onlyOwner {
        require(_amount < rewardToken.balanceOf(address(this)), 'not enough token');
        rewardsToken.transfer(address(msg.sender), _amount);
    }
    */
    
    
    modifier reward_request
    {
        if(ISimplifiedGlobalFarm(globalFarm).rewardMintingAvailable(address(this)))
        {
            ISimplifiedGlobalFarm(globalFarm).mintFarmingReward(address(this));
        }
        _;
    }
    
    function rescueERC20(address token, address to) external onlyOwner {
        require(token != address(rewardsToken), "Reward token is not prone to ERC20 issues");
        require(token != address(lpToken), "LP token is not prone to ERC20 issues");
        
        uint256 value = IERC223(token).balanceOf(address(this));
        IERC223(token).transfer(to, value);
    }
}
