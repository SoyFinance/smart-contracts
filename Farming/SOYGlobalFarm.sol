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
    }
    
    IMintableToken public rewardsToken;          // SOY token
    uint256 public tokensPerYear = 50 * 10**6 * 10*18;  // 50M tokens
    uint256 public totalMultipliers;
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

    function getLocalFarmId(address _localFarm) external view returns (uint256) {
        return localFarmId[_localFarm];
    }

    function addLocalFarm(address _localFarmAddress, uint32 _multiplier) external onlyOwner {
        require(localFarmId[_localFarmAddress] == 0,  "LocalFarm with this address already exists");
        
        // Increment last index before adding a farm.
        // Farm with index = 0 is considered non-existing.
        lastAddedFarmIndex++;
        
        //localFarms.push(LocalFarm(_localFarm, _multiplier));
        
        localFarms[lastAddedFarmIndex].farmAddress = _localFarmAddress;
        localFarms[lastAddedFarmIndex].multiplier  = _multiplier;
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
        
        localFarms[localFarmId[_localFarmAddress]].farmAddress = address(0);
        localFarms[localFarmId[_localFarmAddress]].multiplier  = 0;
        
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
        require (nextMint[_localFarmAddress] < block.timestamp);
        
        
        uint256 amount = tokensPerYear * _period / 365 days; // for all farms
        amount = amount * localFarms[localFarmId[_localFarmAddress]].multiplier / totalMultipliers; // amount per local farm
        
        nextMint[_localFarmAddress] = nextMint[_localFarmAddress] + _period;
        
        rewardsToken.mint(_localFarmAddress, amount);
        ILocalFarm(_localFarmAddress).notifyRewardAmount(amount);
    }
}
