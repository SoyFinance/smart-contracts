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
    address public constant SOY_TOKEN = 0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65;
    address public constant globalFarm = 0x64Fa36ACD0d13472FD786B03afC9C52aD5FCf023;
    uint256 public constant BONUS_LIMIT = 10;   // maximum bonus percentage can be bought
    address public bonusToken;  // token address 
    uint256[] internal bonusPrice;    // bonus percentage = index + 1 (i.e. 1% = index 0), value price in bonusToken (from lower to higher)

    //========== TESTNET VALUES ===========
    //https://github.com/SoyFinance/smart-contracts/tree/main/Farming#testsoy223-token
    //address public constant SOY_TOKEN = 0x4c20231BCc5dB8D805DB9197C84c8BA8287CbA92;

    // https://github.com/SoyFinance/smart-contracts/tree/main/Farming#test-global-farm-contract-3-minutes
    //address public constant globalFarm = 0x9F66541abc036503Ae074E1E28638b0Cb6165458;
    //========== END TEST VALUES ==========

    bool public isEnabled;
    uint256 public totalShares; // effective total shares included bonuses
    uint256 public totalStaked; // total staked amount on contract

    struct Staker {
        uint256 amount;
        uint256 rewardPerSharePaid;
        uint64 endTime; // Time when staking ends and user may withdraw. After this time user will not receive rewards.
        uint64 index; // Balances indexed
        uint64 bonus;   // percent of bonus applied
        uint64 affiliatePercent; // percent of user's rewards that will be transferred to affiliate, i.e. 5% 
        address affiliate; // address of affiliate
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
    uint256 public affiliatePercent; // percent of user's rewards that will be transferred to affiliate, i.e. 5% 
    uint256 public noAffiliatePercent; // percent of user's rewards will be paid if no affiliate. 
                                    // i.e. 90% means that user will receive only 90% of his rewards if it come without affiliate,
                                    // but if there is affiliate (with 5%) than user will receive 95% and affiliate receive 5% of reward.

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
    event SetAffiliatePercentage(uint256 _affiliatePercent, uint256 _noAffiliatePercent);

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
        if (msg.sender == bonusToken && _value != 0) {
            uint256 bonus;
            require(_data.length == 32, "Wrong bonus percentage");
            bonus = abi.decode(_data, (uint256));  // _data should contain ABI encoded UINT =  bonus percentage
            _buyBonus(_from, _value, bonus);
            return;
        }
        require(msg.sender == SOY_TOKEN, "Only SOY staking is supported");
        if (_from == globalFarm || _from == owner()) return; // if globalFarm or admin transfer tokens, they will be added to reward pool
        address _affiliate;
        if (_data.length == 32) _affiliate = abi.decode(_data, (address)); // _data should contain ABI encoded affiliate address 
        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        // May not accept deposit from other contracts due GAS limit.
        startStaking(_from, _value, _affiliate);
    }

    // Add tokens to the unlocked staking. Reward is transferred to user
    function startStaking(address user, uint256 amount, address affiliate) internal {
        require(isEnabled, "staking disabled");
        if (staker[user].endTime != 0) {
            if (staker[user].endTime < block.timestamp) {
                _withdraw(user); // withdraw if lock expired
                return;
            } else {
                require(amount == 0, "Account locked for staking");
            }
        }
        update(0);
        if (affiliate != address(0) && staker[user].affiliate == address(0)) { // if affiliate was not set before
            // add affiliate
            staker[user].affiliate = affiliate;
            staker[user].affiliatePercent = uint64(affiliatePercent);
        }
        totalStaked += amount;
        totalShares += (amount * (100 + staker[user].bonus) / 100); // multiply staked amount by bonus multiplier
        (uint256 userReward, uint256 affiliateRewardOrRest) = _pendingReward(user, accumulatedRewardPerShare);
        staker[user].amount += amount;
        staker[user].rewardPerSharePaid = accumulatedRewardPerShare;
        // transfer affiliate reward of split the rest
        if (affiliateRewardOrRest != 0) {
            affiliate = staker[user].affiliate;
            if (affiliate != address(0)) {
                // transfer affiliate reward to affiliate address
                IERC223(SOY_TOKEN).transfer(affiliate, affiliateRewardOrRest); // transfer rewards to user
            } else {
                accumulatedRewardPerShare += (affiliateRewardOrRest * 1e18 / totalShares); // split the rest among shareholders
            }
        }
        IERC223(SOY_TOKEN).transfer(user, userReward); // transfer rewards to user
        emit StartStaking(user, amount, block.timestamp);
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address user) public view returns (uint256 userReward) {
        uint256 _alignedTime = (block.timestamp / 1 hours) * 1 hours; // aligned by 1 hour
        uint256 _lastRewardTimestamp = lastRewardTimestamp;
        uint256 _accumulatedRewardPerShare = accumulatedRewardPerShare;
        if (_alignedTime <= _lastRewardTimestamp) {
            (userReward,) = _pendingReward(user, _accumulatedRewardPerShare);
            return userReward;
        }
        uint256 _totalShares = totalShares;
        uint256 _reward = getRewardPerSecond() * getAllocationX1000() * 1e15; // 1e15 = 1e18 / 1000;
        uint256 timePassed;
        uint256 i = startIndex; // start from
        uint256 maxRecords = balances.length;
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
            if (staker[user].endTime != 0 && staker[user].index == i) {
                // found block where user's stake end
                (userReward,) =  _pendingReward(user, _accumulatedRewardPerShare);
                return userReward;
            }
        }
        timePassed = _alignedTime - _lastRewardTimestamp;
        if (_totalShares != 0) {
            _accumulatedRewardPerShare =
                _accumulatedRewardPerShare +
                ((timePassed * _reward) / _totalShares);
        }
        (userReward,) = _pendingReward(user, _accumulatedRewardPerShare);
        return userReward;
    }

    // Calculate pending reward of user
    function _pendingReward(address user, uint256 _accumulatedRewardPerShare) internal view returns (uint256 userReward, uint256 affiliateRewardOrRest) {
        uint256 shares = staker[user].amount * (100 + staker[user].bonus) / 100;
        if (staker[user].endTime != 0 && startIndex > staker[user].index) {
            // use accumulatedRewardPerShare stored on the moment when staking ends
            _accumulatedRewardPerShare = balances[uint256(staker[user].index)]
                .balanceReduceOrRewardPerShare;
        }
        uint256 reward = (shares * (_accumulatedRewardPerShare - staker[user].rewardPerSharePaid)) / 1e18; // total reward
        if (staker[user].affiliate == address(0)) { // no affiliate
            userReward = reward * noAffiliatePercent / 100;
            affiliateRewardOrRest = reward - userReward;    // rest of rewards that should be added to rewards pool. 
        } else {
            affiliateRewardOrRest = reward * staker[user].affiliatePercent / 100; // affiliate reward
            userReward = reward - affiliateRewardOrRest;
        }
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
        if  (_totalShares != 0) {
            accumulatedRewardPerShare =
                _accumulatedRewardPerShare +
                ((timePassed * _reward) / _totalShares);
        } else {
            accumulatedRewardPerShare = _accumulatedRewardPerShare;
        }
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
        if (balances.length != 0 && balances[balances.length - 1].atTime == endTime) {
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
        (uint256 userReward, uint256 affiliateRewardOrRest) = _pendingReward(user, accumulatedRewardPerShare);
        address affiliate = staker[user].affiliate;
        totalStaked -= amount;
        delete staker[user];
        // transfer affiliate reward of split the rest
        if (affiliateRewardOrRest != 0) {
            if (affiliate != address(0)) {
                // transfer affiliate reward to affiliate address
                IERC223(SOY_TOKEN).transfer(affiliate, affiliateRewardOrRest); // transfer rewards to user
            } else {
                accumulatedRewardPerShare += (affiliateRewardOrRest * 1e18 / totalShares); // split the rest among shareholders
            }
        }
        IERC223(SOY_TOKEN).transfer(user, amount + userReward);
        emit WithdrawStake(user, amount, userReward);
    }

    // buy bonus percent using bonusTokens (using approve - transferFrom pattern)
    function buyBonus(uint256 bonus) external {
        _buyBonus(msg.sender, 0, bonus);
    }

    // buy bonus percent using ERC223 bonusTokens 
    function _buyBonus(address user, uint256 value, uint256 bonus) internal {
        require(staker[user].endTime == 0, "Account locked for staking");
        update(0);
        (uint256 userReward, uint256 affiliateRewardOrRest) = _pendingReward(user, accumulatedRewardPerShare);
        staker[user].rewardPerSharePaid = accumulatedRewardPerShare;
        // user can buy bonus multiplier
        uint256 amount = getBonusPrice(bonus, user);  // get difference in price between current and wanted bonuses
        require(amount != 0, "user already has this bonus");
        if (value == 0) {
            // if was not sent ERC223 then use transferFrom 
            IERC223(bonusToken).transferFrom(user, address(this), amount);
            value = amount;
        }
        require(amount == value, "user transferred wrong amount");
        _safeBurn(amount);   // burn bonus token
        // apply bonus
        uint256 bonusShares = (bonus - staker[user].bonus) * staker[user].amount / 100; // just bought bonus * staking amount
        totalShares += bonusShares;
        staker[user].bonus = uint64(bonus);
        // transfer affiliate reward of split the rest
        if (affiliateRewardOrRest != 0) {
            address affiliate = staker[user].affiliate;
            if (affiliate != address(0)) {
                // transfer affiliate reward to affiliate address
                IERC223(SOY_TOKEN).transfer(affiliate, affiliateRewardOrRest); // transfer rewards to user
            } else {
                accumulatedRewardPerShare += (affiliateRewardOrRest * 1e18 / totalShares); // split the rest among shareholders
            }
        }        
        IERC223(SOY_TOKEN).transfer(user, userReward); // transfer rewards to user
    }

    function _safeBurn(uint256 amount) internal {
        try IERC223(bonusToken).burn(amount) returns (bool)   // try to burn bonus token
        { 
            return;
        }
        catch 
        {
            // if burn function is not implemented then transfer to DEAD address
            IERC223(bonusToken).transfer(address(0xdEad000000000000000000000000000000000000), amount);
        }

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

    // set affiliate percent and no affiliate reducing percent
    function setAffiliatePercentage(uint256 _affiliatePercent, uint256 _noAffiliatePercent) external onlyOwner {
        require(_affiliatePercent <= 50 && _noAffiliatePercent <= 50, "Percentage too high");
        affiliatePercent = _affiliatePercent;
        noAffiliatePercent = _noAffiliatePercent;
        emit SetAffiliatePercentage(_affiliatePercent, _noAffiliatePercent);
    }

    // rescue other token if it was transferred to contract
    function rescueTokens(address _token) onlyOwner external {
        if (_token == SOY_TOKEN && totalStaked != 0) return;   // allow rescue SOY tokens when no stake
        uint256 amount = IERC223(_token).balanceOf(address(this));
        IERC223(_token).transfer(msg.sender, amount);
        emit Rescue(_token, amount);
    }

}
