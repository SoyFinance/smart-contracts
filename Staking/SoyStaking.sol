// SPDX-License-Identifier: No License (None)
pragma solidity ^0.6.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint a, uint b) internal pure returns (uint) {
    if (a == 0) {
      return 0;
    }
    uint c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint a, uint b) internal pure returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal pure returns (uint) {
    require(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    require(c >= a);
    return c;
  }
}

interface ISimplifiedGlobalFarm {
    function mintFarmingReward(address _localFarm) external;
    function getAllocationX1000(address _farm) external view returns (uint256);
    function getRewardPerSecond() external view returns (uint256);
    function rewardMintingAvailable(address _farm) external view returns (bool);
    function farmExists(address _farmAddress) external view returns (bool);
}

interface IERC223 {
    /**
     * @dev Returns the balance of the `who` address.
     */
    function balanceOf(address who) external view returns (uint);
        
    /**
     * @dev Transfers `value` tokens from `msg.sender` to `to` address
     * and returns `true` on success.
     */
    function transfer(address to, uint value) external returns (bool success);
        
    /**
     * @dev Transfers `value` tokens from `msg.sender` to `to` address with `data` parameter
     * and returns `true` on success.
     */
    function transfer(address to, uint value, bytes memory data) external returns (bool success);
     
     /**
     * @dev Event that is fired on successful transfer.
     */
    event Transfer(address indexed from, address indexed to, uint value);
    
     /**
     * @dev Additional event that is fired on successful transfer and logs transfer metadata,
     *      this event is implemented to keep Transfer event compatible with ERC20.
     */
    event TransferData(bytes data);
}

contract ColdStaking {
    
    // NOTE: The contract only works for intervals of time > round_interval

    using SafeMath for uint;

    event StartStaking(address addr, uint value, uint amount, uint time, uint end_time);
    event WithdrawStake(address staker, uint amount);
    event Claim(address staker, uint reward);
    event DonationDeposited(address _address, uint value);

    struct Staker
    {
        uint amount;
        uint time;              // Staking start time or last claim rewards
        uint multiplier;        // Rewards multiplier = 0.40 + (0.05 * rounds). [0.45..1] (max rounds 12)
        uint end_time;          // Time when staking ends and user may withdraw. After this time user will not receive rewards.
    }


    uint public LastBlock = block.number;
    uint public Timestamp = now;    //timestamp of the last interaction with the contract.

    uint public TotalStakingWeight; //total weight = sum (each_staking_amount * each_staking_time).
    uint public TotalStakingAmount; //currently frozen amount for Staking.
    uint public StakingRewardPool;  //available amount for paying rewards.
    uint public staking_threshold = 0 ether;

    uint public constant round_interval   = 27 days;     // 1 month.
    uint public constant max_delay        = 365 days;    // 1 year after staking ends.
    uint public constant BlockStartStaking = 7600000;

    uint constant NOMINATOR = 10**18;           // Nominator / denominator used for float point numbers

    address public constant SOY = 0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65;
    address public constant globalFarm = 0x64Fa36ACD0d13472FD786B03afC9C52aD5FCf023;
    uint public stake_until = 1662033600; // 1 September 2022 12:00:00 GMT (all staking should be finished until this time)
    address public admin;   // admin address who can set stake_until

    //========== TESTNET VALUES ===========
    //uint public constant round_interval   = 1 hours; 
    //uint public constant max_delay        = 2 days;
    //uint public constant BlockStartStaking = 0;
    
    //https://github.com/SoyFinance/smart-contracts/tree/main/Farming#testsoy223-token
    //address public constant SOY = 0xC8227f810FB2F4FacBf9D3CAbca21e47f51d87a3;

    // https://github.com/SoyFinance/smart-contracts/tree/main/Farming#test-global-farm-contract-3-minutes
    //address public constant globalFarm = 0xE8B2Fee5D18ec30f5625a5f7F1f06E5df17E1774;
    //========== END TEST VALUES ==========
    
    mapping(address => Staker) public staker;


    constructor() public {
        admin = msg.sender;
    }

    function setStakeUntil(uint newDate) external {
        require(admin == msg.sender, "Only admin");
        stake_until = newDate;
    }

    // ERC223 token transfer callback
    // bytes _data = abi.encode(address receiver, uint256 toChainId)
    function tokenReceived(address _from, uint _value, bytes calldata _data) external {
        require(msg.sender == SOY, "Only SOY");
        if (_from == globalFarm || _from == admin) return; // if globalFarm or admin transfer tokens, they will be added to reward pool

        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        // May not accept deposit from other contracts due GAS limit.
        // by default stake for 1 round
        uint rounds;
        if (_data.length >= 32) {
            rounds = abi.decode(_data, (uint256));  // _data should contain ABI encoded UINT =  number of rounds
        }
        if (rounds == 0) rounds = 1;
        start_staking(_from, _value, rounds);
    }

    function notifyRewardAmount(uint256 reward) external {}

    function reward_request() internal
    {
        if(ISimplifiedGlobalFarm(globalFarm).rewardMintingAvailable(address(this)))
        {
            ISimplifiedGlobalFarm(globalFarm).mintFarmingReward(address(this));
        }
    }

    // update TotalStakingAmount value.
    function new_block(uint amount) internal
    {
        if (block.number > LastBlock)   //run once per block.
        {
            reward_request();
            uint _LastBlock = LastBlock;
            LastBlock = block.number;

            StakingRewardPool = IERC223(SOY).balanceOf(address(this)).sub(TotalStakingAmount + amount);   //fix rewards pool for this block.
            // amount here for case new_block() is calling from start_staking(), and amount will be added to CurrentBlockDeposits.

            //The consensus protocol enforces block timestamps are always at least +1 from their parent, so a node cannot "lie into the past". 
            if (now > Timestamp) //But with this condition I feel safer :) May be removed.
            {
                uint _blocks = block.number - _LastBlock;
                uint _seconds = now - Timestamp;
                if (_seconds > _blocks * 25) //if time goes far in the future, then use new time as 25 second * blocks.
                {
                    _seconds = _blocks * 25;
                }
                TotalStakingWeight += _seconds.mul(TotalStakingAmount);
                Timestamp += _seconds;
            }
        }
    }

    function start_staking(address user, uint amount, uint rounds) internal staking_available
    {
        assert(amount >= staking_threshold);
        require(rounds > 0);
        new_block(amount); //run once per block.
        // to reduce gas cost we will use local variable instead of global
        uint _Timestamp = Timestamp;
        uint staker_amount = staker[user].amount;
        uint r = rounds;
        if (r > 6) r = 6;
        uint multiplier = (40 + (10 * r)) * NOMINATOR / 100;  // staker multiplier = 0.40 + (0.05 * rounds). [0.45..1]
        uint end_time = _Timestamp.add(round_interval.mul(rounds));
        require(end_time <= stake_until, "Too long staking time");  // do not allow stake longer than "stake_until"
        // claim reward if available.
        if (staker_amount > 0)
        {
            if (_Timestamp >= staker[user].time + round_interval)
            { 
                _claim(payable(user)); 
            }
            uint staker_end_time = staker[user].end_time;
            if (staker_end_time > end_time) {
                end_time = staker_end_time;     // Staking end time is the bigger from previous and new one.
                r = (end_time.sub(_Timestamp)).div(round_interval);  // update number of rounds
                if (r > 12) r = 12;
                multiplier = (40 + (5 * r)) * NOMINATOR / 100;  // staker multiplier = 0.40 + (0.05 * rounds). [0.45..1]
            }
            // if there is active staking with bigger multiplier
            if (staker[user].multiplier > multiplier && staker_end_time > _Timestamp) {
                // recalculate multiplier = (staker.multiplier * staker.amount + new.multiplier * new.amount) / ( staker.amount + new.amount)
                multiplier = ((staker[user].multiplier.mul(staker_amount)).add(multiplier.mul(amount))) / (staker_amount.add(amount));
                if (multiplier > NOMINATOR) multiplier = NOMINATOR; // multiplier can't be more then 1
            }
            TotalStakingWeight = TotalStakingWeight.sub((_Timestamp.sub(staker[user].time)).mul(staker_amount)); // remove from Weight
        }

        TotalStakingAmount = TotalStakingAmount.add(amount);
        staker[user].time = _Timestamp;
        staker[user].amount = staker_amount.add(amount);
        staker[user].multiplier = multiplier;
        staker[user].end_time = end_time;

        emit StartStaking(
            user,
            amount,
            staker[user].amount,
            _Timestamp,
            end_time
        );
    }

    function withdraw_stake() external {
        _withdraw_stake(msg.sender);
    }

    function withdraw_stake(address payable user) external {
        _withdraw_stake(user);
    }

    function _withdraw_stake(address payable user) internal
    {
        new_block(0); //run once per block.
        require(Timestamp >= staker[user].end_time); //reject withdrawal before end time.

        uint _amount = staker[user].amount;
        require(_amount != 0);
        // claim reward if available.
        _claim(user); 
        TotalStakingAmount = TotalStakingAmount.sub(_amount);
        TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[user].time)).mul(staker[user].amount)); // remove from Weight.
        
        staker[user].amount = 0;
        IERC223(SOY).transfer(user, _amount);
        emit WithdrawStake(user, _amount);
    }

    //claim rewards
    function claim() external only_staker
    {
        _claim(msg.sender);
    }


    function _claim(address payable user) internal
    {
        new_block(0); //run once per block
        // to reduce gas cost we will use local variable instead of global
        uint _Timestamp = Timestamp;
        if (_Timestamp > staker[user].end_time) _Timestamp = staker[user].end_time; // rewards calculates until staking ends
        uint _StakingInterval = _Timestamp.sub(staker[user].time);  //time interval of deposit.
        if (_StakingInterval >= round_interval)
        {
            uint _CompleteRoundsInterval = (_StakingInterval / round_interval).mul(round_interval); //only complete rounds.
            uint _StakerWeight = _CompleteRoundsInterval.mul(staker[user].amount); //Weight of completed rounds.
            uint _reward = StakingRewardPool.mul(_StakerWeight).div(TotalStakingWeight);  //StakingRewardPool * _StakerWeight/TotalStakingWeight
            _reward = _reward.mul(staker[user].multiplier) / NOMINATOR;   // reduce rewards if staked on less then 12 rounds.
            StakingRewardPool = StakingRewardPool.sub(_reward);
            TotalStakingWeight = TotalStakingWeight.sub(_StakerWeight); // remove paid Weight.

            staker[user].time = staker[user].time.add(_CompleteRoundsInterval); // reset to paid time, staking continue without a loss of incomplete rounds.
	    
            IERC223(SOY).transfer(user, _reward);
            emit Claim(user, _reward);
        }
    }

    //This function may be used for info only. This can show estimated user reward at current time.
    function stake_reward(address _addr) external view returns (uint _reward)
    {
        //require(staker[_addr].amount > 0);

        uint _blocks = block.number - LastBlock;
        uint _seconds = now - Timestamp;
        if (_seconds > _blocks * 25) //if time goes far in the future, then use new time as 25 second * blocks.
        {
            _seconds = _blocks * 25;
        }
        uint _Timestamp = Timestamp + _seconds;
        if (_Timestamp > staker[_addr].end_time) _Timestamp = staker[_addr].end_time; // rewards calculates until staking ends
        uint _TotalStakingWeight = TotalStakingWeight + _seconds.mul(TotalStakingAmount);
        uint _StakingInterval = _Timestamp.sub(staker[_addr].time); //time interval of deposit.
	
        //uint _StakerWeight = _StakingInterval.mul(staker[_addr].amount); //Staker weight.
        uint _CompleteRoundsInterval = (_StakingInterval / round_interval).mul(round_interval); //only complete rounds.
        uint _StakerWeight = _CompleteRoundsInterval.mul(staker[_addr].amount); //Weight of completed rounds.
        uint _StakingRewardPool = IERC223(SOY).balanceOf(address(this)).sub(TotalStakingAmount);
        _reward = _StakingRewardPool.mul(_StakerWeight).div(_TotalStakingWeight);  //StakingRewardPool * _StakerWeight/TotalStakingWeight
        _reward = _reward.mul(staker[_addr].multiplier) / NOMINATOR;   // reduce rewards if staked on less then 12 rounds.
    }

    modifier only_staker
    {
        require(staker[msg.sender].amount > 0);
        _;
    }

    modifier staking_available
    {
        require(block.number >= BlockStartStaking);
        _;
    }

    //return deposit to inactive staker after 1 year when staking ends.
    function report_abuse(address payable _addr) public only_staker
    {
        require(staker[_addr].amount > 0);
        new_block(0); //run once per block.
        require(Timestamp > staker[_addr].end_time.add(max_delay));
        
        uint _amount = staker[_addr].amount;
        
        TotalStakingAmount = TotalStakingAmount.sub(_amount);
        TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[_addr].time)).mul(_amount)); // remove from Weight.

        staker[_addr].amount = 0;
        IERC223(SOY).transfer(_addr, _amount);
    }
}
