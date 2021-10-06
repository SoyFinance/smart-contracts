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
    address private _owner;

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
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
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

/**
 * @dev Interface of the ERC223 standard as defined in the EIP.
 */
interface IERC223 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    
    function transfer(address recipient, uint256 amount, bytes calldata data) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract ERC223Recipient { 
/**
 * @dev Standard ERC223 function that will handle incoming token transfers.
 *
 * @param _from  Token sender address.
 * @param _value Amount of tokens.
 * @param _data  Transaction metadata.
 */
    function tokenReceived(address _from, uint _value, bytes memory _data) external virtual {}
}

contract Airdrop is Ownable, ERC223Recipient {

    struct Setting {
        uint256 amount;
        uint256 duration;   // in days
        uint256 daysPassed;
    }

    struct User {
        uint256 timestamp;
        uint256 amount;
    }

    struct Participants {
        uint256 totalParticipants;
        uint256 addedParticipants;
    }
    
    IERC223 public token;   // token to airdrop
    uint256 constant public lockPeriod = 180;  // 180 days (6 months) lock period
    mapping(uint256 => mapping(address => User)) public receivers; // airdrop ID => user address => amount and timestamp
    mapping(uint256 => mapping(uint256 => Participants)) public participants; // airdrop ID => day => Participants
    Setting[] public airdrops;
    address public system;

    event Rescue(address _token, uint256 _amount);
    event AirdropCreated(uint256 airdropId, uint256 amount, uint256 duration);
    event SetSystem(address _system);
    event Airdropped(uint256 indexed airdropId, address indexed user, uint256 amount);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlySystem() {
        require(system == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor (address _token) {
        token = IERC223(_token);
    }

    function setSystem(address _system) onlyOwner external {
        system = _system;
        emit SetSystem(_system);
    }

    function createAirdrop(uint256 amount, uint256 duration) onlyOwner external returns(uint256 airdropId) {
        airdropId = airdrops.length;
        airdrops.push(Setting(amount, duration, 0));
        emit AirdropCreated(airdropId, amount, duration);
    }

    function getAirdropsLength() external view returns (uint256) {
        return airdrops.length;
    }

    function getUserInfo(address user) external view returns(User[] memory) {
        uint256 len = airdrops.length;
        User[] memory u = new User[](len);
        for (uint i = 0; i < len; i++) {
            u[i] = receivers[i][user];
        }
        return u;
    }
    
    /**
    * @dev Close Airdrop day. Call this function on next day after claiming (after 00:00 UTC)
    *
    * @param airdropId  Airdrop ID.
    * @param day Day number of airdrop. From 1 to airdrop duration
    * @param totalParticipants  Total number of approved user that claim tokens on this day.
    */
    function closeDay(uint256 airdropId, uint256 day, uint256 totalParticipants) onlySystem external {
        require(participants[airdropId][day].totalParticipants == 0, "Day already closed");
        participants[airdropId][day].totalParticipants = totalParticipants;
    }

    /**
    * @dev Add approved users. Call function closeDay() before start add users.
    *
    * @param airdropId  Airdrop ID.
    * @param day Day number of airdrop. From 1 to airdrop duration
    * @param users The array of approved users whose claim tokens on this day. About 100 users in the array.
    */
    function addUsers(uint256 airdropId, uint256 day, address[] calldata users) onlySystem external {
        require(airdrops[airdropId].daysPassed + 1 == day, "Day already passed");
        require(airdrops[airdropId].daysPassed < airdrops[airdropId].duration, "Airdrop ended");
        uint256 timestamp = block.timestamp / 1 days * 1 days;  // align timestamp to 00:00 UTC
        uint256 totalParticipants = participants[airdropId][day].totalParticipants;
        uint256 amount = airdrops[airdropId].amount / (airdrops[airdropId].duration * totalParticipants);
        participants[airdropId][day].addedParticipants += users.length;
        require (participants[airdropId][day].addedParticipants <= totalParticipants, "Too many users");
        if (participants[airdropId][day].addedParticipants == totalParticipants) {
            airdrops[airdropId].daysPassed = airdrops[airdropId].daysPassed + 1;
        }
        for (uint i = 0; i < users.length; i++) {
            if (receivers[airdropId][users[i]].timestamp == 0) {
                receivers[airdropId][users[i]].timestamp = timestamp;
                receivers[airdropId][users[i]].amount = amount;
            }
        }
    }

    /**
    * @dev Claim tokens on users behalf when lock period ends.
    *
    * @param airdropId  Airdrop ID.
    * @param users The array of users whose lock period ended. About 100 users in the array.
    */
    function claimToken(uint256 airdropId, address[] calldata users) external {
        for (uint i = 0; i < users.length; i++) {
            User memory u = receivers[airdropId][users[i]];
            if (u.timestamp + lockPeriod <= block.timestamp && u.amount > 0)  {
                delete receivers[airdropId][users[i]];
                token.transfer(users[i], u.amount);
                emit Airdropped(airdropId, users[i], u.amount);
            }
        }
    }

    function rescueTokens(address _token) onlyOwner external {
        uint256 amount = IERC223(_token).balanceOf(address(this));
        IERC223(_token).transfer(msg.sender, amount);
        emit Rescue(_token, amount);
    }
}
