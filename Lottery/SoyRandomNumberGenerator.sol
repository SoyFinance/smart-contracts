// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// helper methods for interacting with ERC223 tokens and sending CLO that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferCLO(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: CLO_TRANSFER_FAILED');
    }
}

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
    constructor() {
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
}

interface ISoyLottery {
    /**
     * @notice Buy tickets for the current lottery
     * @param _lotteryId: lotteryId
     * @param _ticketNumbers: array of ticket numbers between 1,000,000 and 1,999,999
     * @dev Callable by users
     */
    function buyTickets(uint256 _lotteryId, uint32[] calldata _ticketNumbers) external;

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _lotteryId: lottery id
     * @param _ticketIds: array of ticket ids
     * @param _brackets: array of brackets for the ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external;

    /**
     * @notice Close lottery
     * @param _lotteryId: lottery id
     * @dev Callable by operator
     */
    function closeLottery(uint256 _lotteryId) external;

    /**
     * @notice Draw the final number, calculate reward in Soy per group, and make lottery claimable
     * @param _lotteryId: lottery id
     * @param _autoInjection: reinjects funds into next lottery (vs. withdrawing all)
     * @dev Callable by operator
     */
    function drawFinalNumberAndMakeLotteryClaimable(uint256 _lotteryId, bool _autoInjection) external;

    /**
     * @notice Inject funds
     * @param _lotteryId: lottery id
     * @param _amount: amount to inject in Soy token
     * @dev Callable by operator
     */
    function injectFunds(uint256 _lotteryId, uint256 _amount) external;

    /**
     * @notice Start the lottery
     * @dev Callable by operator
     * @param _endTime: endTime of the lottery
     * @param _priceTicketInSoy: price of a ticket in Soy
     * @param _discountDivisor: the divisor to calculate the discount magnitude for bulks
     * @param _rewardsBreakdown: breakdown of rewards per bracket (must sum to 10,000)
     * @param _treasuryFee: treasury fee (10,000 = 100%, 100 = 1%)
     */
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicketInSoy,
        uint256 _discountDivisor,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external;

    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() external returns (uint256);
}

interface IRandomNumberGenerator {
    /**
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber(uint256 _seed) external;

    /**
     * View latest lotteryId numbers
     */
    function viewLatestLotteryId() external view returns (uint256);

    /**
     * Views random result
     */
    function viewRandomResult() external view returns (uint32);
}


contract RandomNumberGenerator is IRandomNumberGenerator, Ownable {
    using TransferHelper for address;
    address public SoyLottery;
    address public operator;
    uint32 public randomResult;
    uint256 public latestLotteryId;

    struct Entropy {
        uint256 requestId;  // equal to lottery ID that made request
        uint256 seed;   // seed from request
        bytes32 blockHash1; // the prior request block hash 
        uint256 commitBlock;    // block number of commit
        bytes32 secretHash; // hash of secret random number
    }

    Entropy public entropy;

    modifier onlyOperator() {
        require(operator == msg.sender, "Only operator");
        _;
    }

    event GetRandomNumber(uint256 requestId, address requestor);
    event RandomNumber(uint256 rnd);

    

    /**
     * @notice Request randomness from a user-provided seed
     * @param _seed: seed provided by the Soy lottery
     */
    function getRandomNumber(uint256 _seed) external override {
        require(msg.sender == SoyLottery, "Only SoyLottery");
        uint256 requestId = ISoyLottery(SoyLottery).viewCurrentLotteryId();
        entropy.requestId = requestId;
        entropy.seed = _seed;
        entropy.blockHash1 = blockhash(block.number-1);
        entropy.commitBlock = 0;    // clear last record of block number
        emit GetRandomNumber(requestId, msg.sender);
    }

    // Step 1: commit hash (keccak256) of big random number
    function commitSecret(bytes32 secretHash) external onlyOperator {
        require(entropy.commitBlock == 0, "Already committed");
        entropy.commitBlock = block.number;
        entropy.secretHash = secretHash;
    }

    // Step 2: reveal secret at least in 2 block after commitment and not longer than 255 blocks after.
    // generate random number
    function revealSecret(uint256 requestId, uint256 secret) external onlyOperator {
        require(entropy.requestId == requestId, "Wrong requestId");
        require(keccak256(abi.encodePacked(secret)) == entropy.secretHash, "Wrong secret");
        uint256 commitBlock = entropy.commitBlock;
        require(commitBlock != 0 && commitBlock + 1 < block.number, "Reveal not allowed");  // allow reveal at least in 2 blocks after commitment
        if (block.number - commitBlock > 256) {
            entropy.commitBlock = 0;    // allow to repeat commitment
            emit RandomNumber(0);   // random number generating is failed
            return;
        }
        bytes32 blockHash2 = blockhash(commitBlock + 1); // hash of next block after commitment
        uint256 randomness = uint256(keccak256(abi.encodePacked(entropy.seed, entropy.blockHash1, blockHash2, secret)));
        //randomResult = uint32(1000000 + (randomness % 1000000));
        randomResult = uint32(1000 + (randomness % 1000));
        latestLotteryId = ISoyLottery(SoyLottery).viewCurrentLotteryId();
        emit RandomNumber(randomResult);
    }

    // in case of backend error reset current secret and allow to commit new secret
    function resetSecret() external onlyOwner {
        entropy.commitBlock = 0;    // allow to repeat commitment
        emit RandomNumber(0);   // random number generating is failed
        return;
    }
    /**
     * @notice Set the address for the SoyLottery
     * @param _SoyLottery: address of the Soy lottery
     */
    function setLotteryAddress(address _SoyLottery) external onlyOwner {
        SoyLottery = _SoyLottery;
    }

    /**
     * @notice Set the address of operator
     * @param _operator: address of operator
     */
    function setOperatorAddress(address _operator) external onlyOwner {
        operator = _operator;
    }

    /**
     * @notice It allows the admin to withdraw tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function withdrawTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        _tokenAddress.safeTransfer(address(msg.sender), _tokenAmount);
    }

    /**
     * @notice View latestLotteryId
     */
    function viewLatestLotteryId() external view override returns (uint256) {
        return latestLotteryId;
    }

    /**
     * @notice View random result
     */
    function viewRandomResult() external view override returns (uint32) {
        return randomResult;
    }

    // For test only !!!! 
    function testSetRandom(uint32 rnd) external onlyOperator {
        randomResult = rnd;
        latestLotteryId = ISoyLottery(SoyLottery).viewCurrentLotteryId();
        emit RandomNumber(randomResult);
    }
}