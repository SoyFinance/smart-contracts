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

     /**
     * @dev Additional event that is fired on successful transfer and logs transfer metadata,
     *      this event is implemented to keep Transfer event compatible with ERC20.
     */
    event TransferData(bytes data);
}

abstract contract ERC223Recipient { 
    address public vestedToken;
    mapping(address => bool) public depositors; // address of users who has right to deposit and allocate tokens

    modifier onlyDepositor() {
        require(depositors[msg.sender], "Only depositors allowed");
        _;
    }
    /**
    * @dev Standard ERC223 function that will handle incoming token transfers.
    *
    * @param _from  Token sender address.
    * @param _value Amount of tokens.
    * @param _data  Transaction metadata.
    */
    function tokenReceived(address _from, uint256 _value, bytes memory _data) external virtual {
        require(depositors[_from], "Only depositors allowed");
    }

    constructor (address _token) {
        require(_token != address(0));
        vestedToken = _token;
    }
}

contract Vesting is Ownable, ERC223Recipient {
    struct Allocation {
        uint256 amount;             // amount of token
        uint256 unlockPercentage;   // percentage of initially unlocked token
        uint256 startVesting;       // Timestamp (unix time) when starts vesting. First vesting will be at this time
        uint256 vestingPercentage;  // percentage of tokens will be unlocked every interval (i.e. 10% per 30 days)
        uint256 vestingInterval;    // interval (in seconds) of vesting (i.e. 30 days)        
    }

    uint256 public totalAllocated;
    uint256 public totalClaimed;
    mapping(address => Allocation[]) public beneficiaries; // beneficiary => Allocation
    mapping(address => uint256) public claimedAmount;   // beneficiary => already claimed amount

    event SetDepositor(address depositor, bool enable);
    event Claim(address indexed beneficiary, uint256 amount);
    event AddAllocation(
        address indexed to,         // beneficiary of tokens
        uint256 amount,             // amount of token
        uint256 unlockPercentage,   // percentage of initially unlocked token
        uint256 startVesting,       // Timestamp (unix time) when starts vesting. First vesting will be at this time
        uint256 vestingPercentage,  // percentage of tokens will be unlocked every interval (i.e. 10% per 30 days)
        uint256 vestingInterval     // interval (in seconds) of vesting (i.e. 30 days)        
    );
    event Rescue(address _token, uint256 _amount);

    constructor (address _token) ERC223Recipient(_token) {

    }

    // Depositor has right to transfer token to contract and allocate token to the beneficiary
    function setDepositor(address depositor, bool enable) external onlyOwner {
        depositors[depositor] = enable;
        emit SetDepositor(depositor, enable);
    }

    function allocateTokens(
        address to, // beneficiary of tokens
        uint256 amount, // amount of token
        uint256 unlockPercentage,   // percentage of initially unlocked token
        uint256 startVesting,       // Timestamp (unix time) when starts vesting. First vesting will be at this time
        uint256 vestingPercentage,  // percentage of tokens will be unlocked every interval (i.e. 10% per 30 days)
        uint256 vestingInterval     // interval (in seconds) of vesting (i.e. 30 days)
    )
        external
        onlyDepositor
    {
        require(amount <= getUnallocatedAmount(), "Not enough tokens");
        require(startVesting > block.timestamp, "startVesting in the past");
        beneficiaries[to].push(Allocation(amount, unlockPercentage, startVesting, vestingPercentage, vestingInterval));
        totalAllocated += amount;
        // Check ERC223 compatibility of the beneficiary 
        if (isContract(to)) {
            bytes memory _empty = hex"00000000";
            ERC223Recipient(to).tokenReceived(address(this), 0, _empty);
        }

        emit AddAllocation(to, amount, unlockPercentage, startVesting, vestingPercentage, vestingInterval);
    }

    function claim() external {
        claimBehalf(msg.sender);
    }

    function claimBehalf(address beneficiary) public {
        uint256 unlockedAmount = getUnlockedAmount(beneficiary);
        require(unlockedAmount != 0, "No unlocked tokens");
        claimedAmount[beneficiary] += unlockedAmount;
        totalClaimed += unlockedAmount;
        IERC223(vestedToken).transfer(beneficiary, unlockedAmount);
        emit Claim(beneficiary, unlockedAmount);
    }

    function getUnlockedAmount(address beneficiary) public view returns(uint256 unlockedAmount) {
        for (uint256 i = 0; i < beneficiaries[beneficiary].length; i++) {
            Allocation storage b = beneficiaries[beneficiary][i];
            uint256 amount = b.amount;
            uint256 unlocked = amount * b.unlockPercentage / 100;
            if (b.startVesting <= block.timestamp) {
                uint256 intervals = (block.timestamp - b.startVesting) / b.vestingInterval + 1;
                unlocked = unlocked + (amount * intervals * b.vestingPercentage / 100);
            }
            if (unlocked > amount) unlocked = amount;
            unlockedAmount += unlocked;
        }
        unlockedAmount = unlockedAmount - claimedAmount[beneficiary];
    }

    function getUnallocatedAmount() public view returns(uint256 amount) {
        amount = IERC223(vestedToken).balanceOf(address(this));
        uint256 unclaimed = totalAllocated - totalClaimed;
        amount = amount - unclaimed;
    }

    function rescueTokens(address _token) onlyOwner external {
        uint256 amount;
        if (_token == vestedToken) {
            amount = getUnallocatedAmount();
        } else {
            amount = IERC223(_token).balanceOf(address(this));
        }

        IERC223(_token).transfer(msg.sender, amount);
        emit Rescue(_token, amount);
    }

    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}