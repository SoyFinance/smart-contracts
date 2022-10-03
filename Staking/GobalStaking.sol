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
    function approve(address spender, uint256 amount) external returns (bool);
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

interface ILocalFarm {
    function notifyRewardAmount(uint256 reward) external;
    function initialize(
        address _rewardsToken,      // SOY token
        address _lpToken            // LP token that will be staked in this Local Farm
    ) external;
}

interface ISimplifiedGlobalFarm {
    function mintFarmingReward(address _localFarm) external;

    function getAllocationX1000(address _farm) external view returns (uint256);

    function getRewardPerSecond() external view returns (uint256);

    function rewardMintingAvailable(address _farm) external view returns (bool);

    function farmExists(address _farmAddress) external view returns (bool);
}

contract GlobalStaking is Ownable {
    
    struct LocalFarm {
        address farmAddress;
        uint256 multiplier;
        uint256 lastPayment;
    }

    address public constant globalFarm = 0x64Fa36ACD0d13472FD786B03afC9C52aD5FCf023;
    address public constant SOY_TOKEN = 0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65;
    //TEST NET
    //address public constant globalFarm = 0x9F66541abc036503Ae074E1E28638b0Cb6165458;
    //address public constant SOY_TOKEN = 0x4c20231BCc5dB8D805DB9197C84c8BA8287CbA92;

    uint256 public totalMultipliers;
    uint256 public paymentDelay = 1 days;          // DEFAULTS_TO 1 days

    mapping(uint256 => LocalFarm) public localFarms;
    uint256                       public lastAddedFarmIndex = 0; // Farm IDs will start from 1
    
    mapping(address => uint256)   public localFarmId;     // locals farm address => id; localFarm at ID = 0 is considered non-existing

    event AddStaking(address _localFarm, uint32 _multiplier);
    event RemoveStaking(address _localFarm);
    event ChangeMultiplier(address _localFarm, uint256 _oldMultiplier, uint256 _newMultiplier);

    
    function next_payment() public view returns (uint256)
    {
        return (block.timestamp / paymentDelay) * paymentDelay + paymentDelay;
    }
    
    function rewardMintingAvailable(address _farm) public view returns (bool)
    {
        return localFarms[localFarmId[_farm]].lastPayment + paymentDelay <= next_payment();
    }

    function getAllocationX1000(address _farm) public view returns (uint256)
    {
        return 1000 * localFarms[localFarmId[_farm]].multiplier / totalMultipliers;
    }
    
    function getRewardPerSecond() public view returns (uint256)
    {
        uint256 rewardPerSecond = ISimplifiedGlobalFarm(globalFarm).getRewardPerSecond();
        uint256 allocationX1000 = ISimplifiedGlobalFarm(globalFarm).getAllocationX1000(address(this));
        return rewardPerSecond * allocationX1000 / 1000;
    }

    function getLocalFarmId(address _localFarmAddress) external view returns (uint256) {
        return localFarmId[_localFarmAddress];
    }
    
    function getLastPayment(address _localFarmAddress) external view returns (uint256) {
        return localFarms[localFarmId[_localFarmAddress]].lastPayment;
    }

    function addStakingContract(
        address _localFarmAddress,            // staking contract
        uint32 _multiplier
    ) 
        external onlyOwner 
    {
        // Increment last index before adding a farm.
        // Farm with index = 0 is considered non-existing.
        lastAddedFarmIndex++;
        
        localFarms[lastAddedFarmIndex].farmAddress = _localFarmAddress;
        localFarms[lastAddedFarmIndex].multiplier  = _multiplier;
        localFarms[lastAddedFarmIndex].lastPayment = next_payment() - paymentDelay;
        
        localFarmId[_localFarmAddress]             = lastAddedFarmIndex;
        
        totalMultipliers += uint256(_multiplier);
        
        emit AddStaking(_localFarmAddress, _multiplier);
    }

    
    function farmExists(address _farmAddress) public view returns (bool _exists)
    {
        return (localFarmId[_farmAddress] != 0) && (localFarms[localFarmId[_farmAddress]].farmAddress != address(0));
    }

    function removeLocalFarmByAddress(address _localFarmAddress) external onlyOwner {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        
        totalMultipliers = totalMultipliers - uint256(localFarms[localFarmId[_localFarmAddress]].multiplier); // update totalMultipliers
        
        //delete localFarmId[_localFarmAddress];
        
        localFarms[localFarmId[_localFarmAddress]].farmAddress  = address(0);
        localFarms[localFarmId[_localFarmAddress]].multiplier   = 0; // Not critically important, can be removed for gas efficiency reasons.
        localFarms[localFarmId[_localFarmAddress]].lastPayment  = 0; // Not critically important, can be removed for gas efficiency reasons.
        
        localFarmId[_localFarmAddress] = 0;
        
        emit RemoveStaking(_localFarmAddress);
    }


    function changeMultiplier(address _localFarmAddress, uint32 _multiplier) external onlyOwner {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        
        uint256 oldMultiplier = localFarms[localFarmId[_localFarmAddress]].multiplier;
        totalMultipliers = totalMultipliers + uint256(_multiplier) - uint256(oldMultiplier); // update totalMultipliers
        localFarms[localFarmId[_localFarmAddress]].multiplier = _multiplier;
        emit ChangeMultiplier(_localFarmAddress, oldMultiplier, _multiplier);
    }

    function mintFarmingReward(address _localFarmAddress) external {
        require (farmExists(_localFarmAddress), "LocalFarm with this address does not exist");
        
        // Comparing against 0:00 UTC always
        // to enable withdrawals for full days only at any point within 24 hours of a day.
        if(localFarms[localFarmId[_localFarmAddress]].lastPayment + paymentDelay > next_payment())
        {
            // Someone is requesting payment for a Local Farm that was paid recently.
            // Do nothing.
            return;
        }
        else
        {
            ISimplifiedGlobalFarm(globalFarm).mintFarmingReward(address(this));
            uint256 _reward = (next_payment() - localFarms[localFarmId[_localFarmAddress]].lastPayment) * getRewardPerSecond() * getAllocationX1000(_localFarmAddress) / 1000;
            localFarms[localFarmId[_localFarmAddress]].lastPayment = next_payment();
            IERC223(SOY_TOKEN).transfer(_localFarmAddress, _reward);
            ILocalFarm(_localFarmAddress).notifyRewardAmount(_reward);
        }
    }

    function notifyRewardAmount(uint256 reward) external {}
    function tokenReceived(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external {
        require(_from == globalFarm, "Only globalFarm");
    }
}
