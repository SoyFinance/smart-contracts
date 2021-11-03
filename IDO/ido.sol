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
/*    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
*/
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


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

interface IPriceFeed {
    function getPrice(address token) external view returns(uint256);
}

contract IDO is Ownable, ReentrancyGuard {
    struct Round {
        uint256 soyToSell;  // amount of SOY sell in this round
        uint256 usdCollected;   // USD value received in this round
        uint256 hardCap;    // maximum amount of USD that can be collected by this round
        uint256 softCap;    // minimum amount of USD to collect
        uint256 start;  // timestamp when auction start
        uint256 end;    // timestamp when auction end
    }

    struct Bet {
        uint256 usdValue;       // contributed usd in this round
        uint256 soyAmount;      // amount locked SOY
        uint256 lockedUntil;    // locked until
    }

    //mapping(uint256 => mapping(address => AcceptedToken)) public totalBets; // auction => token address => AcceptedToken
    mapping(uint256 => mapping(address => Bet)) public bets;    // round ID => user address => Bet
    mapping(uint256 => Round) public auctionRound; // round ID => Round
    mapping(address => bool) public allowedToken;   // token accepted for payment
    bool public isPaused;
    address constant public SoyToken = address(0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65);
    uint256 constant public RATIO = 1017233603000000000; // 1.017233603
    address constant public priceFeed = address(0x9bFc3046ea26f8B09D3E85bd22AEc96C80D957e3);   // price feed contract
    address payable public bank;    // receiver of bets tokens
    uint256 public totalSoyToSell;  // total amount of Soy to sell
    uint256 public totalSoySold;    // total amount of sold Soy including Soy in active auction.
    uint256 public auctionRounds;   // number of auction rounds
    uint256 public currentRoundId;  // current auction round (round starts from 1)


    //uint256 public soyPerAuctionPeriod;
    uint256 public roundDuration;  // auction round duration (in seconds).
    uint256 public lockPeriod;   // period while tokens will be locked
    uint256 public lockPercentage;  // percentage of bought tokens that will be locked
    uint256 public minPricePercentage;  // percentage of previous auction price assign to min price
    uint256 public maxPricePercentage;  // maxPrice = lastRoundSoyPrice * maxPricePercentage / 100
    uint256 public lastRoundSoyPrice;       // previous auction price
    uint256 public maxExtendRounds;    // maximum number of rounds to extend tha auction


    event RoundEnds(uint256 indexed roundID, uint256 soySold, uint256 usdCollected);
    event Rescue(address _token, uint256 _amount);
    event SetBank(address _bank);
    event UserBet(uint256 indexed roundID, address indexed user, address indexed token, uint256 usdValue, uint256 tokenAmount);

    modifier notPaused() {
        require(!isPaused, "Paused");
        _;
    }

    function initialize() external {
        require(_owner == address(0), "Already initialized");
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        lockPeriod = 365 days;   // period while tokens will be locked
        minPricePercentage = 90;  // percentage of previous auction price assign to min price
        maxExtendRounds = 3;    // maximum number of rounds to extend the auction

        /*// weekly auction
        roundDuration = 7 days;  // auction round duration (in seconds).
        maxPricePercentage = 500; // maxPrice = lastRoundSoyPrice * maxPricePercentage / 100
        lockPercentage = 70;    // 50% of Soy will be locked
        auctionRounds = 26;   // number of auction rounds
        */
        // daily auction
        roundDuration = 1 days;  // auction round duration (in seconds).
        maxPricePercentage = 160; // maxPrice = lastRoundSoyPrice * maxPricePercentage / 100
        lockPercentage = 50;    // 50% of Soy will be locked
        auctionRounds = 180;   // number of auction rounds
    }

    function setPause(bool state) external onlyOwner {
        isPaused = state;
    }

    function setBank(address payable _bank) onlyOwner external
    {
        require(_bank != address(0), "Zero address not allowed");
        bank = _bank;
        emit SetBank(_bank);
    }

    function setLastRoundSoyPrice(uint256 val) external onlyOwner {
        lastRoundSoyPrice = val;
    }

    function setMinPricePercentage(uint256 val) external onlyOwner {
        minPricePercentage = val;
    }

    function setMaxPricePercentage(uint256 val) external onlyOwner {
        maxPricePercentage = val;
    }

    function setLockPercentage(uint256 val) external onlyOwner {
        lockPercentage = val;
    }

    function setLockPeriod(uint256 val) external onlyOwner {
        lockPeriod = val;
    }

    function setRoundDuration(uint256 val) external onlyOwner {
        roundDuration = val;
    }

    function setMaxExtendRounds(uint256 val) external onlyOwner {
        maxExtendRounds = val;
    }

    function setAuctionRounds(uint256 val) external onlyOwner {
        require(val >= currentRoundId);
        auctionRounds = val;
    }

    function setAllowedToken(address token, bool state) external onlyOwner {
        require(token != address(0));
        allowedToken[token] = state;
    }

    // set amount to sell at current round
    function setRoundSellAmount(uint256 amount) external onlyOwner {
        uint256 currentAmount = auctionRound[currentRoundId].soyToSell;
        totalSoySold = totalSoySold + amount - currentAmount;
        require(totalSoyToSell >= totalSoySold, "Wrong amount");
        auctionRound[currentRoundId].soyToSell = amount;
        auctionRound[currentRoundId].hardCap = amount * lastRoundSoyPrice * maxPricePercentage / 10**20;    // 100 * 10**18
        auctionRound[currentRoundId].softCap = amount * lastRoundSoyPrice * minPricePercentage / 10**20;    // 100 * 10**18
    }

    function auctionStart(uint256 startTime, uint256 soyPrice) external onlyOwner {
        require(currentRoundId == 0, "Only start once");
        require(totalSoyToSell != 0, "No SOY to sell");
        lastRoundSoyPrice = soyPrice;
        auctionRound[0].soyToSell = 29491750873668297408771; // auctionRound[0] * RATIO / 10**18 == 30 000 SOY for first day in daily auction.
        startRound(startTime);
    }

    function claim() external {
        claimBehalf(msg.sender, 1, currentRoundId);
    }

    function claimBehalf(address user) public {
        claimBehalf(user, 1, currentRoundId);
    }

    // claim SOY tokens from numbers of auction rounds (fromRound to toRound). toRound is excluded.
    function claimBehalf(address user, uint256 fromRound, uint256 toRound) public nonReentrant {
        require(fromRound < toRound && toRound <= currentRoundId, "Incorrect rounds parameters");
        uint256 soyToClaim;
        uint256 _lockPercentage = lockPercentage;
        uint256 _lockPeriod = lockPeriod;
        for (uint256 i = fromRound; i<toRound; i++) {
            uint256 usdValue = bets[i][user].usdValue;
            if (usdValue != 0) { // user contributed in this round
                if (bets[i][user].lockedUntil == 0) { // receive token from round
                    uint256 total = auctionRound[i].soyToSell * usdValue / auctionRound[i].usdCollected;
                    uint256 locked = total * _lockPercentage / 100;
                    soyToClaim += (total - locked);
                    bets[i][user].soyAmount = locked;
                    bets[i][user].lockedUntil = auctionRound[i].end + _lockPeriod;
                    bets[i][user].usdValue = 0;
                }
            }
            // Check if can claim locked tokens 
            uint256 soyAmount = bets[i][user].soyAmount;
            if (soyAmount != 0 && bets[i][user].lockedUntil < block.timestamp) {
                soyToClaim += soyAmount;
                bets[i][user].soyAmount = 0;
            }
        }
        IERC223(SoyToken).transfer(user, soyToClaim);
    }

    // return amount of SOY tokens that user may claim and amount that locked
    function getTokenToClaim(address user) external view returns(uint256 soyToClaim, uint256 soyLocked) {
        uint256 toRound = currentRoundId;
        uint256 _lockPercentage = lockPercentage;
        uint256 _lockPeriod = lockPeriod;
        for (uint256 i = 1; i < toRound; i++) {
            uint256 usdValue = bets[i][user].usdValue;
            if (usdValue != 0) { // user contributed in this round
                uint256 lockedUntil = bets[i][user].lockedUntil;
                uint256 locked;
                if (lockedUntil == 0) { // receive token from round
                    uint256 total = auctionRound[i].soyToSell * usdValue / auctionRound[i].usdCollected;
                    locked = total * _lockPercentage / 100;
                    soyToClaim += (total - locked);
                    lockedUntil = auctionRound[i].end + _lockPeriod;
                }
                if (lockedUntil < block.timestamp) {
                    soyToClaim += bets[i][user].soyAmount;
                    soyToClaim += locked;   // in case of user do first claim in 1 year after auction end.
                } else {
                    soyLocked += bets[i][user].soyAmount;
                }
            } else if (bets[i][user].soyAmount != 0){
                if (bets[i][user].lockedUntil < block.timestamp) {
                    soyToClaim += bets[i][user].soyAmount;
                } else {
                    soyLocked += bets[i][user].soyAmount;
                }
            }
        }
    }

    // Returns arrays of locked SOY, unlock timestamp, SOY price (in USD with 18 decimals). Array index 0 = round 1 and so on.
    // And total amount of SOY that user may claim and amount of SOY that is locked.
    function getUserDetail(address user) external view 
    returns(uint256[] memory lockedSoy, uint256[] memory lockedDate, uint256[] memory soyPrice, uint256 soyToClaim, uint256 soyLocked) 
    {
        uint256 currentRound = currentRoundId;
        lockedSoy = new uint256[](currentRound-1);
        lockedDate = new uint256[](currentRound-1);
        soyPrice = new uint256[](currentRound-1);

        uint256 _lockPercentage = lockPercentage;
        uint256 _lockPeriod = lockPeriod;
        for (uint256 i = 1; i < currentRound; i++) {
            uint256 usdValue = bets[i][user].usdValue;
            if (usdValue != 0) { // user contributed in this round
                uint256 lockedUntil = bets[i][user].lockedUntil;
                uint256 locked;
                if (lockedUntil == 0) { // receive token from round
                    uint256 total = auctionRound[i].soyToSell * usdValue / auctionRound[i].usdCollected;
                    locked = total * _lockPercentage / 100;
                    soyToClaim += (total - locked);
                    lockedUntil = auctionRound[i].end + _lockPeriod;
                    lockedDate[i-1] = lockedUntil;
                    lockedSoy[i-1] = locked;
                    soyPrice[i-1] = auctionRound[i].usdCollected * 10**18 / auctionRound[i].soyToSell;
                }
                if (lockedUntil < block.timestamp) {
                    soyToClaim += bets[i][user].soyAmount;
                    soyToClaim += locked;   // in case of user do first claim in 1 year after auction end.
                } else {
                    soyLocked += bets[i][user].soyAmount;
                }
            } else if (bets[i][user].soyAmount != 0){
                lockedDate[i-1] = bets[i][user].lockedUntil;
                lockedSoy[i-1] = bets[i][user].soyAmount;
                soyPrice[i-1] = auctionRound[i].usdCollected * 10**18 / auctionRound[i].soyToSell;                
                if (lockedDate[i-1] < block.timestamp) {
                    soyToClaim += lockedSoy[i-1];
                } else {
                    soyLocked += lockedSoy[i-1];
                }
            }
        }
    }

    
    // returns USD value collected in the current round and total USD value collected during the auction
    function getCollectedUSD() external view returns(uint256 currentRoundUSD, uint256 totalUSD) {
        uint256 currentRound = currentRoundId;
        currentRoundUSD = auctionRound[currentRound].usdCollected;
        for (uint i=1; i<=currentRound; i++) {
            totalUSD = auctionRound[i].usdCollected;
        }
    }

    // returns USD value collected in the round
    function getCollectedUSD(uint256 round) external view returns(uint256) {
        return auctionRound[round].usdCollected;
    }

    // Bet with ERC223 token
    function tokenReceived(address _from, uint _value, bytes calldata _data) external {
        if (msg.sender == SoyToken && _from == owner()) {
            totalSoyToSell += _value;
            return;
        }
        require(allowedToken[msg.sender], "Token isn't allowed");
        userBet(_from, msg.sender, _value); // user, token, amount
    }

    receive() external payable {
        makeBet(address(1), msg.value);
    }

    // make bet to Auction
    function makeBet(address token, uint256 amount) public payable  {
        require(allowedToken[token], "Token isn't allowed");
        if (token == address(1)) {
            require(amount == msg.value, "Incorrect CLO amount");
        } else {
            require(msg.value == 0, "Only token");
            IERC223(token).transferFrom(msg.sender, address(this), amount);
        }
        userBet(msg.sender, token, amount);
    }

    function userBet(address user, address token, uint256 amount) internal notPaused nonReentrant {
        if (checkRound()) // if last round finished - return money to sender.
        {
            transferTo(token, amount, user);
            return;
        }
        uint256 roundID = currentRoundId;
        uint256 price = getPrice(token);
        Round storage round = auctionRound[roundID];
        Bet storage bet = bets[roundID][user];
        uint256 totalUSD = round.usdCollected + (amount * price / 10**18);
        if (totalUSD >= round.hardCap) {
            uint256 rest = totalUSD - round.hardCap; // rest of USD
            rest = rest * 10**18 / price; // rest in token
            if (rest > amount) rest = amount; // this condition shouldn't be true but added to be safe.
            round.usdCollected = round.hardCap;
            amount = amount - rest; // amount of token that bet in this round
            endRound(block.timestamp);
            if (rest != 0) transferTo(token, rest, user); // return rest to the user
        } else {
            round.usdCollected = totalUSD;
        }
        uint256 usdValue = amount * price / 10**18;
        bet.usdValue += usdValue;    // update user's bet
        transferTo(token, amount, bank);    // transfer token to the bank address
        emit UserBet(roundID, user, token, usdValue, amount);
    }

    function startRound(uint256 startTime) internal {
        currentRoundId++;
        require(currentRoundId <= auctionRounds, "All rounds completed");
        Round storage round = auctionRound[currentRoundId];
        round.start = startTime;
        round.end = startTime + roundDuration;
        // calculate amount of Soy to sell per round.
        uint256 soyToSell;
        if (roundDuration == 1 days) {
            soyToSell = auctionRound[currentRoundId - 1].soyToSell * RATIO / 10**18;
            if ((totalSoyToSell - totalSoySold) < soyToSell) {
                soyToSell = totalSoyToSell - totalSoySold;  // if left less Soy then we need due to calculation - sell all available Soy
            }
        } else {
            uint256 roundsLeft = auctionRounds + 1 - currentRoundId;
            soyToSell = (totalSoyToSell - totalSoySold) / roundsLeft;
        }

        round.soyToSell = soyToSell;
        totalSoySold += soyToSell;
        round.hardCap = soyToSell * lastRoundSoyPrice * maxPricePercentage / 10**20;    // 100 * 10**18
        round.softCap = soyToSell * lastRoundSoyPrice * minPricePercentage / 10**20;    // 100 * 10**18
    }

    // return true if last auction round finished
    function endRound(uint256 endTime) internal returns(bool isLastRoundEnd) {
        Round storage round = auctionRound[currentRoundId];
        lastRoundSoyPrice = round.usdCollected * 10**18 / round.soyToSell;
        emit RoundEnds(currentRoundId, round.soyToSell, round.usdCollected);
        if (currentRoundId == auctionRounds) {  // last round
            currentRoundId++;
            isLastRoundEnd = true;
        } else {
            startRound(endTime);  // start new round when previous round ends
        }
    }

    // return true if last auction round finished
    function checkRound() internal returns(bool isLastRoundEnd) {
        Round storage round = auctionRound[currentRoundId];
        require(round.start <= block.timestamp, "Auction is not started yet");
        require(currentRoundId <= auctionRounds, "Auction is finished");
        require(round.soyToSell != 0, "No SOY to sell");
        if (round.end <= block.timestamp) { // auction round finished.
            if (round.usdCollected < round.softCap) {
                // extend auction on next round duration if min threshold was not reached
                uint256 duration = (block.timestamp - round.start) / roundDuration;
                if (duration < maxExtendRounds) {
                    round.end = round.start + ((duration+1)*roundDuration);
                } else {
                    round.end = round.start + (maxExtendRounds * roundDuration);
                    isLastRoundEnd = endRound(round.end);
                }
            } else {
                isLastRoundEnd = endRound(round.end);
            }
        }
    }


    function transferTo(address token, uint256 amount, address receiver) internal {
        if (token == address(1)) {   // transfer CLO 
            payable(receiver).transfer(amount);
        } else {
            IERC223(token).transfer(receiver, amount);
        }
    }

    // get price of token from price feed contract (price in USD with 18 decimals)
    function getPrice(address token) internal view returns(uint256 price) {
        return IPriceFeed(priceFeed).getPrice(token);
    }

    function rescueTokens(address _token) onlyOwner external {
        uint256 amount;
        if (_token == SoyToken) {
            amount = totalSoyToSell-totalSoySold;
            totalSoyToSell = totalSoySold;
        } else {
            amount = IERC223(_token).balanceOf(address(this));
        }
        IERC223(_token).transfer(msg.sender, amount);
        emit Rescue(_token, amount);
    }
}
