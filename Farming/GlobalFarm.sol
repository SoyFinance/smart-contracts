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

interface IERC20 {
    function mint(address _to, uint256 _amount) external;
}

interface ILocalFarm {
    function notifyRewardAmount(uint256 reward) external;
}

contract GlobalFarm is Ownable {
    struct LocalFarm {
        address localFarm;
        uint32 multiplier;
    }
    
    IERC20 public rewardsToken; // SOY token
    uint256 public tokensPerYear = 50 * 10**6 * 10*18;  // 50M tokens
    uint256 public totalMultipliers;
    LocalFarm[] public localFarms;  // local farms list
    mapping(address => uint256) localFarmId; // locals farm address => id in list (1 based)
    mapping(address => uint256) public nextMint; // timestamp when token may be minted to local farm


    event AddLocalFarm(address _localFarm, uint32 _multiplier);
    event RemoveLocalFarm(address _localFarm);
    event ChangeMultiplier(address _localFarm, uint32 _oldMultiplier, uint32 _newMultiplier);
    event ChangeTokenPerYear(uint256 oldAmount, uint256 newAmount);

    constructor (address _rewardsToken) {
        rewardsToken = IERC20(_rewardsToken);
    }

    function getLocalFarmId(address _localFarm) external view returns (uint256) {
        uint256 valueIndex =  localFarmId[_localFarm];
        require (valueIndex != 0, "LocalFarm not exist");
        return valueIndex - 1;
    }

    function addLocalFarm(address _localFarm, uint32 _multiplier) external onlyOwner {
        require(localFarmId[_localFarm] == 0,  "LocalFarm exist");
        localFarms.push(LocalFarm(_localFarm, _multiplier));
        localFarmId[_localFarm] = localFarms.length;
        totalMultipliers += uint256(_multiplier);
        emit AddLocalFarm(_localFarm, _multiplier);
    }

    function removeLocalFarm(address _localFarm) external onlyOwner {
        uint256 valueIndex = localFarmId[_localFarm];
        require (valueIndex != 0, "LocalFarm not exist"); 

        uint256 toDeleteIndex = valueIndex - 1;
        uint256 lastIndex = localFarms.length - 1;
        totalMultipliers = totalMultipliers - uint256(localFarms[toDeleteIndex].multiplier); // update totalMultipliers

        // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
        // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

        LocalFarm memory lastvalue = localFarms[lastIndex];
        // Move the last value to the index where the value to delete is
        localFarms[toDeleteIndex] = lastvalue;
        // Update the index for the moved value
        localFarmId[lastvalue.localFarm] = toDeleteIndex + 1; // All indexes are 1-based

        // Delete the slot where the moved value was stored
        localFarms.pop();
        // Delete the index for the deleted slot
        delete localFarmId[_localFarm];
        emit RemoveLocalFarm(_localFarm);
    }


    function changeMultiplier(address _localFarm, uint32 _multiplier) external onlyOwner {
        uint256 valueIndex = localFarmId[_localFarm];
        require (valueIndex != 0, "LocalFarm not exist");
        valueIndex--;
        uint32 oldMultiplier = localFarms[valueIndex].multiplier;
        totalMultipliers = totalMultipliers + uint256(_multiplier) - uint256(oldMultiplier); // update totalMultipliers
        localFarms[valueIndex].multiplier = _multiplier;
        emit ChangeMultiplier(_localFarm, oldMultiplier, _multiplier);
    }

    function changeTokenPerYear(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = tokensPerYear;
        tokensPerYear = newAmount;
        emit ChangeTokenPerYear(oldAmount, newAmount);
    }

    function mintFarming(address _localFarm, uint256 _period) external {
        uint256 valueIndex = localFarmId[_localFarm];
        require (valueIndex != 0, "LocalFarm not exist");
        require (nextMint[_localFarm] < block.timestamp);
        valueIndex--;
        uint256 amount = tokensPerYear * _period / 365 days; // for all farms
        amount = amount * localFarms[valueIndex].multiplier / totalMultipliers; // amount per local farm
        nextMint[_localFarm] = nextMint[_localFarm] + _period;
        rewardsToken.mint(_localFarm, amount);
        ILocalFarm(_localFarm).notifyRewardAmount(amount);
    }
}