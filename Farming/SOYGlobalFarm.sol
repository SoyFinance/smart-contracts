// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;



/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}


/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
    /**
     * @dev Searches a sorted `array` and returns the first index that contains
     * a value greater or equal to `element`. If no such index exists (i.e. all
     * values in the array are strictly less than `element`), the array length is
     * returned. Time complexity O(log n).
     *
     * `array` is expected to be sorted in ascending order, and to contain no
     * repeated elements.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 *
 * Source https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-solidity/v2.1.3/contracts/ownership/Ownable.sol
 * This contract is copied here and renamed from the original to avoid clashes in the compiled artifacts
 * when the user imports a zos-lib contract (that transitively causes this contract to be compiled and added to the
 * build/artifacts folder) as well as the vanilla Ownable implementation from an openzeppelin version.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(),"Not Owner");
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0),"Zero address not allowed");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IMintableToken {
    function mint(address _to, uint256 _amount) external;
}

interface ILocalFarm {
    function notifyRewardAmount(uint256 reward) external;
}

contract GlobalFarm is Ownable {
    
    using Arrays for uint256[];
    using Counters for Counters.Counter;
    
    struct LocalFarm {
        address farmAddress;
        uint32  multiplier;
        uint256 lastMintTimestamp;
    }

    // Snapshotted values have arrays of ids and the value corresponding to that id. These could be an array of a
    // Snapshot struct, but that would impede usage of functions that work on an array.
    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }
    
    mapping(address => Snapshots) private _farmMultiplierSnapshot;
    Snapshots private _totalMultipliersSnapshot;
    Snapshots private _tokensPerYearSnapshot;

    // Snapshot ids increase monotonically, with the first value being 1. An id of 0 is invalid.
    Counters.Counter private _currentSnapshotId;
    
    IMintableToken public rewardsToken;                 // SOY token
    uint256 public tokensPerYear  = 50 * 10**6 * 10*18;  // 50M tokens
    uint256 public totalMultipliers;
    uint256 public rewardDuration = 1 days;
    
    uint256 public activeSnapshotId = 1;  // Contract operates by two types of snapshots
                                          // getCurrentSnapshotId() - returns an "internal" workaround snapshot which can store queued values
                                          // activeSnapshotId       - returns an actual snapshot ID which can be equal to getCurrentSnapshotId()-1 if pending snapshot is not yet applied
    
    uint256 public pendingNextSnapshotTimestamp = 0;
    //LocalFarm[] public localFarms;               // local farms list
    
    mapping(uint256 => LocalFarm) public localFarms;
    uint256                       public lastAddedFarmIndex = 0; // Farm IDs will start from 1
    
    mapping(address => uint256)   public localFarmId;     // locals farm address => id; localFarm at ID = 0 is considered non-existing
    mapping(address => uint256)   public nextMint; // timestamp when token may be minted to local farm

    event AddLocalFarm(address _localFarm, uint32 _multiplier);
    event RemoveLocalFarm(address _localFarm);
    event ChangeMultiplier(address _localFarm, uint32 _oldMultiplier, uint32 _newMultiplier);
    event ChangeTokenPerYear(uint256 oldAmount, uint256 newAmount);

    constructor (address _rewardsToken) {
        rewardsToken = IMintableToken(_rewardsToken);
    }
    
    // ======== Snapshotting ============ //
    
    function maintenance() public
    {
        if(pendingNextSnapshotTimestamp != 0 && pendingNextSnapshotTimestamp < block.timestamp)
        {
            // We only increment actual snapshot on the next day after changes were pushed to pending snapshot.
            activeSnapshotId++;
            pendingNextSnapshotTimestamp = 0;
        }
    }
    
    
    /**
     * @dev Creates a new snapshot and returns its snapshot id.
     *
     * Emits a {Snapshot} event that contains the same id.
     *
     * {_snapshot} is `internal` and you have to decide how to expose it externally. Its usage may be restricted to a
     * set of accounts, for example using {AccessControl}, or it may be open to the public.
     *
     * [WARNING]
     * ====
     * While an open way of calling {_snapshot} is required for certain trust minimization mechanisms such as forking,
     * you must consider that it can potentially be used by attackers in two ways.
     *
     * First, it can be used to increase the cost of retrieval of values from snapshots, although it will grow
     * logarithmically thus rendering this attack ineffective in the long term. Second, it can be used to target
     * specific accounts and increase the cost of ERC223 transfers for them, in the ways specified in the Gas Costs
     * section above.
     *
     * We haven't measured the actual numbers; if this is something you're interested in please reach out to us.
     * ====
     */
    function _snapshot() internal virtual returns (uint256) {
        _currentSnapshotId.increment();
        
        return getCurrentSnapshotId();
    }
    
    function getCurrentSnapshotId() public view returns (uint256) {
        return _currentSnapshotId.current();
    }
    
    function farmMultiplierAt(address _localFarmAddress, uint256 _snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(_snapshotId, _farmMultiplierSnapshot[_localFarmAddress]);

        return snapshotted ? value : localFarms[localFarmId[_localFarmAddress]].multiplier;
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots) private view returns (bool, uint256) {
        require(snapshotId > 0, "Snapshot id is 0");
        require(snapshotId <= getCurrentSnapshotId(), "Nonexistent id");

        // When a valid snapshot is queried, there are three possibilities:
        //  a) The queried value was not modified after the snapshot was taken. Therefore, a snapshot entry was never
        //  created for this id, and all stored snapshot ids are smaller than the requested one. The value that corresponds
        //  to this id is the current one.
        //  b) The queried value was modified after the snapshot was taken. Therefore, there will be an entry with the
        //  requested id, and its value is the one to return.
        //  c) More snapshots were created after the requested one, and the queried value was later modified. There will be
        //  no entry for the requested id: the value that corresponds to it is that of the smallest snapshot id that is
        //  larger than the requested one.
        //
        // In summary, we need to find an element in an array, returning the index of the smallest value that is larger if
        // it is not found, unless said value doesn't exist (e.g. when all values are smaller). Arrays.findUpperBound does
        // exactly this.

        uint256 index = snapshots.ids.findUpperBound(snapshotId);

        if (index == snapshots.ids.length) {
            return (false, 0);
        } else {
            return (true, snapshots.values[index]);
        }
    }

    function _updateFarmMultipliersSnapshot(address _localFarmAddress, uint256 _amount) private {
        _updateSnapshot(_farmMultiplierSnapshot[_localFarmAddress], _amount);
    }

    function _updateTotalMultipliersSnapshot(uint256 _amount) private {
        _updateSnapshot(_totalMultipliersSnapshot, _amount);
    }

    function _updateTokensPerYearSnapshot(uint256 _amount) private {
        _updateSnapshot(_tokensPerYearSnapshot, _amount);
    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        // Whenever changes to snapshottable variables are proposed for the first time of each snapshot it creates a new "pending" snapshot
        // _snapshot() function increments the value of "getCurrentSnapshotId"
        // it is assumed that all related Local Farm contract operate based on actualSnapshotId which stays unchanged for 1 day since proposed changes
        // the purpose of pending snapshots is to accumulate all proposed during one day changes and then apply them at once in the next snapshot
        // so that to avoid creating numerous separate snapshots for every update and increasing gas costs.
        
        // Upon updating any snapshot queue new pendingEpoch
        if(pendingNextSnapshotTimestamp == 0)
        {
            pendingNextSnapshotTimestamp = next_day_zero_timestamp();
            _snapshot();
        }
        
        uint256 currentId = getCurrentSnapshotId();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }
    
    function totalMultipliersAt(uint256 snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalMultipliersSnapshot);

        return snapshotted ? value : totalMultipliers;
    }
    // ======== ============ =============== //
    
    function today_zero_timestamp() public view returns (uint256)
    {
        return (block.timestamp / 1 days) * 1 days;
    }
    
    function next_day_zero_timestamp() public view returns (uint256)
    {
        return ( (block.timestamp / 1 days) * 1 days) + 1 days;
    }

    function getLocalFarmId(address _localFarmAddress) external view returns (uint256) {
        return localFarmId[_localFarmAddress];
    }
    
    function getLastMintTimestamp(address _localFarmAddress) external view returns (uint256) {
        return localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp;
    }

    function addLocalFarm(address _localFarmAddress, uint32 _multiplier) external onlyOwner {
        require(localFarmId[_localFarmAddress] == 0,  "LocalFarm with this address already exists");
        
        // Updating snapshots first.
        _updateFarmMultipliersSnapshot(_localFarmAddress, _multiplier);
        _updateTotalMultipliersSnapshot(totalMultipliers + _multiplier);
        
        // Increment last index before adding a farm.
        // Farm with index = 0 is considered non-existing.
        lastAddedFarmIndex++;
        
        //localFarms.push(LocalFarm(_localFarm, _multiplier));
        
        localFarms[lastAddedFarmIndex].farmAddress       = _localFarmAddress;
        localFarms[lastAddedFarmIndex].multiplier        = _multiplier;
        localFarms[lastAddedFarmIndex].lastMintTimestamp = block.timestamp;
        
        localFarmId[_localFarmAddress]             = lastAddedFarmIndex;
        
        totalMultipliers += uint256(_multiplier);
        
        emit AddLocalFarm(_localFarmAddress, _multiplier);
    }

    function addLocalFarmAtID(address _localFarmAddress, uint256 _id, uint32 _multiplier) external onlyOwner {
        
        // Allows adding farm at given ID if it is empty as a result of previous farm removal
        require(localFarmId[_localFarmAddress] == 0,  "LocalFarm with this address already exists");
        require(_id != 0,  "LocalFarm at address 0 is considered non-existing by system");
        require(_id < lastAddedFarmIndex, "Can not add farms ahead of autoincremented index");
        
        _updateFarmMultipliersSnapshot(_localFarmAddress, _multiplier);
        _updateTotalMultipliersSnapshot(totalMultipliers + _multiplier);
        
        localFarms[_id].farmAddress = _localFarmAddress;
        localFarms[_id].multiplier  = _multiplier;
        localFarmId[_localFarmAddress]             = _id;
        
        totalMultipliers += uint256(_multiplier);
        
        emit AddLocalFarm(_localFarmAddress, _multiplier);
    }
    
    function farmExists(address _farmAddress) public view returns (bool _exists)
    {
        return (localFarmId[_farmAddress] != 0) && (localFarms[localFarmId[_farmAddress]].farmAddress != address(0));
    }

    function removeLocalFarmByAddress(address _localFarmAddress) external onlyOwner {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        require (localFarmId[_localFarmAddress] != 0, "LocalFarm with this address does not exist"); 
        
        _updateFarmMultipliersSnapshot(_localFarmAddress, 0);
        _updateTotalMultipliersSnapshot(totalMultipliers - localFarms[localFarmId[_localFarmAddress]].multiplier);
        
        totalMultipliers = totalMultipliers - uint256(localFarms[localFarmId[_localFarmAddress]].multiplier); // update totalMultipliers
        
        //delete localFarmId[_localFarmAddress];
        
        localFarms[localFarmId[_localFarmAddress]].farmAddress        = address(0);
        localFarms[localFarmId[_localFarmAddress]].multiplier         = 0; // Not critically important, can be removed for gas efficiency reasons.
        localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp  = 0; // Not critically important, can be removed for gas efficiency reasons.
        
        localFarmId[_localFarmAddress] = 0;
        
        emit RemoveLocalFarm(_localFarmAddress);
    }


    function changeMultiplier(address _localFarmAddress, uint32 _multiplier) external onlyOwner {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        
        uint32 oldMultiplier = localFarms[localFarmId[_localFarmAddress]].multiplier;
        totalMultipliers = totalMultipliers + uint256(_multiplier) - uint256(oldMultiplier); // update totalMultipliers
        localFarms[localFarmId[_localFarmAddress]].multiplier = _multiplier;
        
        _updateFarmMultipliersSnapshot(_localFarmAddress, _multiplier);
        _updateTotalMultipliersSnapshot(totalMultipliers);
        
        emit ChangeMultiplier(_localFarmAddress, oldMultiplier, _multiplier);
    }

    function changeTokenPerYear(uint256 newAmount) external onlyOwner {
        
        _updateTokensPerYearSnapshot(newAmount);
        
        uint256 oldAmount = tokensPerYear;
        tokensPerYear = newAmount;
        emit ChangeTokenPerYear(oldAmount, newAmount);
    }

    function mintFarmingReward(address _localFarmAddress, uint256 _period) external {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        require (_period > 0, "Cannot claim reward for a timeframe of 0 seconds");
        
        maintenance();
        
        //require (nextMint[_localFarmAddress] < block.timestamp); // Can not place a "requirement" on auto-executable function.
        
        // This function can be called by EVERYONE.
        // Nothing happens if the `rewardDuration` time has not passed since the last minting for this Local Farm,
        // Or minting session happens for this Local Farm:
        // minting session can be (1) for the full duration (now - last minting session for this Local Farm)
        // or (2) for part of the available for minting period in case _period is less than (now - last minting session for this Local Farm).
        
        if(localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp + rewardDuration < block.timestamp)
        {
            // We should check if sufficient time since the last minting session passed for this Local Farm.
            
            if(_period < block.timestamp - localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp)
            {
                // Claiming for less-than-maximum period.
                // This can be necessary if the contract stayed without claiming for too long
                // and the accumulated reward can not be minted in one transaction.
                
                // In this case this function `mintFarmingReward` can be manually claimed by a user multiple times
                // in order to mint reward part-by-part.
                
                // Last Mint Timestamp of the local farm must be updated to match the time preriod
                // that user already claimed reward for.
                
                localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp += _period;
            }
            else
            {
                // Otherwise the reward is distributed for the total reward period duration,
                // it is important to note that user can not cause the contract to print reward in the future.
                
                _period = block.timestamp - localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp;
                localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp = block.timestamp;
            }
            
            // Reward is then calculated based on the _period
            // it can be either "specified period" or "now - Local Farm's previous minting timestamp".
            uint256 amount = tokensPerYear * _period / 365 days; // for all farms
            amount = amount * localFarms[localFarmId[_localFarmAddress]].multiplier / totalMultipliers; // amount per local farm
        
            // Local farm is then notified about the reward minting session.
            rewardsToken.mint(_localFarmAddress, amount);
            ILocalFarm(_localFarmAddress).notifyRewardAmount(amount);
        }
        
        // Otherwise if the previous minting session occured recently and the time condition was not met
        // this function does nothing. It should not revert execution
        // because it is automatically called by Local Farms sometimes
        // therefore the call will not fail but the minting will simply not happen.
    }
}
