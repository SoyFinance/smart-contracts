// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;

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
    
    struct LocalFarm {
        address farmAddress;
        uint32  multiplier;
        uint256 lastMintTimestamp;
    }
    
    IMintableToken public rewardsToken;                 // SOY token
    uint256 public tokensPerYear = 50 * 10**6 * 10*18;  // 50M tokens
    uint256 public totalMultipliers;
    uint256 public rewardDuration = 1 days;
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

    function getLocalFarmId(address _localFarmAddress) external view returns (uint256) {
        return localFarmId[_localFarmAddress];
    }
    
    function getLastMintTimestamp(address _localFarmAddress) external view returns (uint256) {
        return localFarms[localFarmId[_localFarmAddress]].lastMintTimestamp;
    }

    function addLocalFarm(address _localFarmAddress, uint32 _multiplier) external onlyOwner {
        require(localFarmId[_localFarmAddress] == 0,  "LocalFarm with this address already exists");
        
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
        require(localFarmId[_localFarmAddress] == 0,  "LocalFarm with this address already exists");
        require(_id != 0,  "LocalFarm at address 0 is considered non-existing by system");
        require(_id < lastAddedFarmIndex, "Can not add farms ahead of autoincremented index");
        
        // Increment last index before adding a farm.
        
        //localFarms.push(LocalFarm(_localFarm, _multiplier));
        
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
        emit ChangeMultiplier(_localFarmAddress, oldMultiplier, _multiplier);
    }

    function changeTokenPerYear(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = tokensPerYear;
        tokensPerYear = newAmount;
        emit ChangeTokenPerYear(oldAmount, newAmount);
    }

    function mintFarmingReward(address _localFarmAddress, uint256 _period) external {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        require (_period > 0, "Cannot claim reward for a timeframe of 0 seconds");
        //require (nextMint[_localFarmAddress] < block.timestamp); // Can not place a "requirement" on auto-executable function.
        
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
