// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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
    function balanceOf(address who) external view returns (uint256);

    /**
     * @dev Transfers `value` tokens from `msg.sender` to `to` address
     * and returns `true` on success.
     */
    function transfer(address to, uint256 value)
        external
        returns (bool success);

    /**
     * @dev Transfers `value` tokens from `msg.sender` to `to` address with `data` parameter
     * and returns `true` on success.
     */
    function transfer(
        address to,
        uint256 value,
        bytes memory data
    ) external returns (bool success);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount) external returns (bool);

    /**
     * @dev Event that is fired on successful transfer.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Additional event that is fired on successful transfer and logs transfer metadata,
     *      this event is implemented to keep Transfer event compatible with ERC20.
     */
    event TransferData(bytes data);
}

contract SoyStaking is Ownable {
    address public constant SOY = 0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65;
    address public constant globalFarm = 0x64Fa36ACD0d13472FD786B03afC9C52aD5FCf023;
    uint256 public constant BONUS_LIMIT = 10;   // maximum bonus percentage can be bought
    address public bonusToken;  // token address 
    uint256[] internal bonusPrice;    // bonus percentage = index + 1 (i.e. 1% = index 0), value price in bonusToken (from lower to higher)

    //========== TESTNET VALUES ===========
    //https://github.com/SoyFinance/smart-contracts/tree/main/Farming#testsoy223-token
    //address public constant SOY = 0x4c20231BCc5dB8D805DB9197C84c8BA8287CbA92;

    // https://github.com/SoyFinance/smart-contracts/tree/main/Farming#test-global-farm-contract-3-minutes
    //address public constant globalFarm = 0x84122f45f224f9591C13183675477AA62e993B13;
    //========== END TEST VALUES ==========

    bool public isEnabled;
    uint256 public totalShares; // effective total shares included bonuses
    uint256 public totalStaked; // total staked amount on contract (just for info)

    struct Staker {
        uint256 amount;
        uint256 rewardPerSharePaid;
        uint64 endTime; // Time when staking ends and user may withdraw. After this time user will not receive rewards.
        uint64 index; // Balances indexed
        uint64 bonus;   // percent of bonus applied  
    }
    mapping(address => Staker) public staker;

    struct Balance {
        uint256 atTime; // time when reduce balance
        uint256 balanceReduceOrRewardPerShare; // amount to reduce balance or reward per share at time
        //uint256 rewardPerShare; // reward per share at time
    }

    Balance[] public balances;
    uint256 public startIndex; // start index of unprocessed balances records
    uint256 public accumulatedRewardPerShare;
    uint256 public lastRewardTimestamp;
    uint256 public lockTime; // in seconds, time that tokens should be locked when user call unlock()

    event StartStaking(
        address staker,
        uint256 amount,
        uint256 time
    );

    event WithdrawRequest(
        address staker,
        uint256 alignedTime,
        uint256 stakedAmount
    );

    event WithdrawStake(
        address staker, 
        uint256 amount, 
        uint256 reward
    );

    event Rescue(address _token, uint256 _amount);

    constructor(uint256 _lockTime) {
        lockTime = _lockTime;
    }

    function enableStaking(bool enable) external onlyOwner {
        isEnabled = enable;
    }

    function getRewardPerSecond() public view returns (uint256) {
        return ISimplifiedGlobalFarm(globalFarm).getRewardPerSecond();
    }

    function getAllocationX1000() public view returns (uint256) {
        return
            ISimplifiedGlobalFarm(globalFarm).getAllocationX1000(address(this));
    }

    function notifyRewardAmount(uint256 reward) external {}

    // ERC223 token transfer callback
    // bytes _data = abi.encode(address receiver, uint256 toChainId)
    function tokenReceived(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external {
        require(msg.sender == SOY, "Only SOY");
        if (_from == globalFarm || _from == owner()) return; // if globalFarm or admin transfer tokens, they will be added to reward pool

        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        // May not accept deposit from other contracts due GAS limit.
        startStaking(_from, _value);
    }

    // Add tokens to the unlocked staking. Reward is transferred to user
    function startStaking(address user, uint256 amount) internal {
        require(staker[user].endTime == 0, "Account locked for staking");
        require(isEnabled, "staking disabled");
        update(0);
        totalStaked += amount;
        totalShares += (amount * (100 + staker[user].bonus) / 100); // multiply staked amount by bonus multiplier
        uint256 userReward = pendingReward(user);
        staker[user].amount += amount;
        staker[user].rewardPerSharePaid = accumulatedRewardPerShare;
        IERC223(SOY).transfer(user, userReward); // transfer rewards to user
        emit StartStaking(user, amount, block.timestamp);
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address user) public view returns (uint256) {
        uint256 _accumulatedRewardPerShare = accumulatedRewardPerShare;
        uint256 shares = staker[user].amount * (100 + staker[user].bonus) / 100;
        if (staker[user].endTime != 0 && startIndex > staker[user].index) {
            // use accumulatedRewardPerShare stored on the moment when staking ends
            _accumulatedRewardPerShare = balances[uint256(staker[user].index)]
                .balanceReduceOrRewardPerShare;
        }
        return
            (shares *
                (_accumulatedRewardPerShare -
                    staker[user].rewardPerSharePaid)) / 1e18;
    }

    // update total balance and accumulatedRewardPerShare regarding ended staking
    // process "maxRecords" at a time. If maxRecords == 0, process all pending records
    function update(uint256 maxRecords) public {
        uint256 _alignedTime = (block.timestamp / 1 hours) * 1 hours; // aligned by 1 hour
        uint256 _lastRewardTimestamp = lastRewardTimestamp;
        if (_alignedTime <= _lastRewardTimestamp) {
            return;
        }
        uint256 _totalShares = totalShares;
        if (_totalShares == 0) {
            lastRewardTimestamp = _alignedTime;
            return;
        }
        ISimplifiedGlobalFarm(globalFarm).mintFarmingReward(address(this));
        uint256 _reward = getRewardPerSecond() * getAllocationX1000() * 1e15; // 1e15 = 1e18 / 1000;
        uint256 _accumulatedRewardPerShare = accumulatedRewardPerShare;
        uint256 timePassed;
        uint256 i = startIndex; // start from
        maxRecords = maxRecords + i; // last record
        if (maxRecords == i || balances.length < maxRecords)
            maxRecords = balances.length;
        for (; i < maxRecords; i++) {
            if (balances[i].atTime > _alignedTime) break; // future record
            timePassed = balances[i].atTime - _lastRewardTimestamp;
            _lastRewardTimestamp = balances[i].atTime;
            _accumulatedRewardPerShare =
                _accumulatedRewardPerShare +
                ((timePassed * _reward) / _totalShares);
            _totalShares =
                _totalShares -
                balances[i].balanceReduceOrRewardPerShare;
            balances[i]
                .balanceReduceOrRewardPerShare = _accumulatedRewardPerShare; // using the same variable reduce gas usage by 15K
        }
        startIndex = i;
        totalShares = _totalShares;
        timePassed = _alignedTime - _lastRewardTimestamp;
        lastRewardTimestamp = _alignedTime;
        accumulatedRewardPerShare =
            _accumulatedRewardPerShare +
            ((timePassed * _reward) / _totalShares);
    }

    // Withdraw request lock staking for lockTime.
    // User can't add more tokens to locked staking
    function withdrawRequest() external {
        uint256 stakedAmount = staker[msg.sender].amount;
        require(
            staker[msg.sender].endTime == 0 && stakedAmount != 0,
            "withdraw request already made"
        );
        update(0);
        uint256 endTime = ((block.timestamp + lockTime) / 1 hours) * 1 hours; // staking end time aligned by 1 hour
        staker[msg.sender].endTime = uint64(endTime);
        emit WithdrawRequest(msg.sender, endTime, stakedAmount);
        uint256 bonus = staker[msg.sender].bonus * stakedAmount / 100;
        stakedAmount = stakedAmount + bonus; // effective share = staked amount + bonus
        if (balances[balances.length - 1].atTime == endTime) {
            // we have records for current hour
            balances[balances.length - 1]
                .balanceReduceOrRewardPerShare += stakedAmount;
        } else {
            balances.push(Balance(endTime, stakedAmount));
        }
        staker[msg.sender].index = uint64(balances.length - 1);
    }

    //withdraw tokens from staking
    function withdraw() external {
        _withdraw(msg.sender);
    }

    // withdraw tokens from staking on user behalf
    function withdraw(address user) external {
        _withdraw(user);
    }

    function _withdraw(address user) internal {
        require(
            staker[user].endTime < block.timestamp && staker[user].endTime != 0,
            "withdrawal locked"
        );
        update(0);
        uint256 amount = staker[user].amount;
        uint256 reward = pendingReward(user);
        totalStaked -= amount;
        delete staker[user];
        IERC223(SOY).transfer(user, amount + reward);
        emit WithdrawStake(user, amount, reward);
    }

    // buy bonus percent using bonusTokens
    function buyBonus(uint256 bonus) external {
        require(staker[msg.sender].endTime == 0, "Account locked for staking");
        update(0);
        uint256 userReward = pendingReward(msg.sender);
        staker[msg.sender].rewardPerSharePaid = accumulatedRewardPerShare;
        // user can buy bonus multiplier
        uint256 amount = getBonusPrice(bonus, msg.sender);  // get difference in price between current and wanted bonuses
        require(amount != 0, "user already has this bonus");
        IERC223(bonusToken).transferFrom(msg.sender, address(this), amount);
        IERC223(bonusToken).burn(amount);   // burn bonus token
        // apply bonus
        uint256 bonusShares = (bonus - staker[msg.sender].bonus) * staker[msg.sender].amount / 100; // just bought bonus * staking amount
        totalShares += bonusShares;
        staker[msg.sender].bonus = uint64(bonus);
        IERC223(SOY).transfer(msg.sender, userReward); // transfer rewards to user
    }

    // return amount that user has to pay to buy bonus percentage (from 1 to BONUS_LIMIT)
    function getBonusPrice(uint256 bonus, address user) public view returns(uint256 amount) {
        require(bonus !=0 && bonus <= bonusPrice.length, "incorrect bonus");
        uint256 alreadyPaid;
        uint256 userBonus = staker[user].bonus;
        if(bonus <= userBonus) return 0; // user already has this or better bonus
        if (userBonus != 0) alreadyPaid = bonusPrice[userBonus-1];   // 1% = index 0, 2% = index 1, ...
        amount = bonusPrice[bonus-1] - alreadyPaid;
    }

    // return array of prices. Index + 1 = percent of bonus.
    // I.e. [0] = price of 1% bonus, [1] - price of 2% bonus, ..., [9] - price of 10% bonus
    function getBonusPrices() external view returns(uint256[] memory) {
        return bonusPrice;
    }

    // bonusPrices is array of prices. Index + 1 = percent of bonus.
    // I.e. [0] = price of 1% bonus, [1] - price of 2% bonus, ..., [9] - price of 10% bonus
    function setBonusPrices(uint256[] memory bonusPrices) external onlyOwner {
        delete bonusPrice;
        require(bonusPrices.length <= BONUS_LIMIT, "Too big bonus");
        bonusPrice = bonusPrices;
    }

    // set contract address of token that accept to buy bonus
    function setBonusToken(address _bonusToken) external onlyOwner {
        bonusToken = _bonusToken;
    }

    // rescue other token if it was transferred to contract
    function rescueTokens(address _token) onlyOwner external {
        if (_token == SOY) return;
        uint256 amount = IERC223(_token).balanceOf(address(this));
        IERC223(_token).transfer(msg.sender, amount);
        emit Rescue(_token, amount);
    }

}
