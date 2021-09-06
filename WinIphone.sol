/**
 *Submitted for verification at BscScan.com on 2021-09-05
*/

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

/**
 * Standard SafeMath, stripped down to just add/sub/mul/div
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () public {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
 * BEP20 standard interface.
 */
interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minimumTokenBalanceForDividends) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
    function claimDividend() external;
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IBEP20 ADA = IBEP20(0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47);
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IDEXRouter router;

    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 1 hours; // min 1 hour delay
    uint256 public minDistribution = 1 * (10 ** 18); // 1 ADA minimum auto send
    uint256 public minimumTokenBalanceForDividends = 100000 * (10**9); // user must hold 100,000 token

    uint256 currentIndex;

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor () {
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _token = msg.sender;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minimumTokenBalanceForDividends) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
        minimumTokenBalanceForDividends = _minimumTokenBalanceForDividends;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > minimumTokenBalanceForDividends && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount <= minimumTokenBalanceForDividends && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function getAccount(address _account) public view returns(
        address account,
        uint256 pendingReward,
        uint256 totalRealised,
        uint256 lastClaimTime,
        uint256 nextClaimTime,
        uint256 secondsUntilAutoClaimAvailable){
        account = _account;
        pendingReward = getUnpaidEarnings(account);
        totalRealised = shares[_account].totalRealised;
        lastClaimTime = shareholderClaims[_account];
        nextClaimTime = lastClaimTime + minPeriod;
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function deposit() external payable override onlyToken {
        uint256 balanceBefore = ADA.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(ADA);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amount = ADA.balanceOf(address(this)).sub(balanceBefore);

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }
    
    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
                && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0){ return; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            ADA.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }
    
    function claimDividend() external override {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}


contract SafeToken is Ownable {
    address payable safeManager;

    constructor() {
        safeManager = payable(msg.sender);
    }

    function setSafeManager(address payable _safeManager) public onlyOwner {
        safeManager = _safeManager;
    }

    function withdraw(address _token, uint256 _amount) external {
        require(msg.sender == safeManager);
        IBEP20(_token).transfer(safeManager, _amount);
    }

    function withdrawBNB(uint256 _amount) external {
        require(msg.sender == safeManager);
        safeManager.transfer(_amount);
    }
}

contract LockToken is Ownable {
    bool public isOpen = false;
    mapping(address => bool) private _whiteList;
    modifier open(address from, address to) {
        require(isOpen || _whiteList[from] || _whiteList[to], "Not Open");
        _;
    }

    constructor() {
        _whiteList[msg.sender] = true;
        _whiteList[address(this)] = true;
    }

    function openTrade() external onlyOwner {
        isOpen = true;
    }

    function includeToWhiteList(address[] memory _users) external onlyOwner {
        for(uint8 i = 0; i < _users.length; i++) {
            _whiteList[_users[i]] = true;
        }
    }
}

contract JackPot {
    using SafeMath for uint256;
    // User data Lottery
    struct userData {
        address userAddress;
        uint256 totalWon;
        uint256 lastWon;
        uint256 index;
        bool tokenOwner;
    }
    // Last person who won, and the amount.
    uint256 private lastWinner_value;
    address private lastWinner_address;

    // -- Global stats --
    uint256 private _allWon;
    uint256 private _countUsers = 0;
    uint8 private w_rt = 0;
    uint256 private _txCounter = 0;

    address immutable ADA = 0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47;

    // Lottery
    mapping(address => bool) public _isExcludedFromLottery;
    mapping(address => userData) private userByAddress;
    mapping(uint256 => userData) private userByIndex;

    // Lottery variables.
    uint256 private transactionsSinceLastLottery = 0;
    uint256 public winAmount;
    uint256 public minBalance;

    event LotteryWon(address winner, uint256 amount);
    event LotterySkipped(address skippedAddress, uint256 _potAmount);

    constructor () {
        _isExcludedFromLottery[address(this)] = true;
        winAmount = 500 * 10**18; // win amount 500 ADA
        minBalance = 100000 * 10**9; // minimumhold 100000 WINIPHONE
    }

    function random(uint256 _totalPlayers, uint8 _w_rt)
        internal
        view
        returns (uint256)
    {
        uint256 w_rnd_c_1 = block.number.add(_txCounter).add(_totalPlayers);
        uint256 w_rnd_c_2 = _allWon;
        uint256 _rnd = 0;
        if (_w_rt == 0) {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number.sub(1)),
                        w_rnd_c_1,
                        blockhash(block.number.sub(2)),
                        w_rnd_c_2
                    )
                )
            );
        } else if (_w_rt == 1) {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number.sub(1)),
                        blockhash(block.number.sub(2)),
                        blockhash(block.number.sub(3)),
                        w_rnd_c_1
                    )
                )
            );
        } else if (_w_rt == 2) {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number.sub(1)),
                        blockhash(block.number.sub(2)),
                        w_rnd_c_1,
                        blockhash(block.number.sub(3))
                    )
                )
            );
        } else if (_w_rt == 3) {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        w_rnd_c_1,
                        blockhash(block.number.sub(1)),
                        blockhash(block.number.sub(3)),
                        w_rnd_c_2
                    )
                )
            );
        } else if (_w_rt == 4) {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        w_rnd_c_1,
                        blockhash(block.number.sub(1)),
                        w_rnd_c_2,
                        blockhash(block.number.sub(2)),
                        blockhash(block.number.sub(3))
                    )
                )
            );
        } else if (_w_rt == 5) {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number.sub(1)),
                        w_rnd_c_2,
                        blockhash(block.number.sub(3)),
                        w_rnd_c_1
                    )
                )
            );
        } else {
            _rnd = uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number.sub(1)),
                        w_rnd_c_2,
                        blockhash(block.number.sub(2)),
                        w_rnd_c_1,
                        blockhash(block.number.sub(2))
                    )
                )
            );
        }
        _rnd = _rnd % _totalPlayers;
        return _rnd;
    }

    function _checkLottery(address recipient) internal returns (bool) {
        if (!isUser(recipient)) {
            insertUser(recipient, 0);
        }

        if (_countUsers == 1) {
            return false;
        }

        // Increment counter
        transactionsSinceLastLottery = transactionsSinceLastLottery.add(1);
        _txCounter = _txCounter.add(1);

        uint256 _pot = IBEP20(ADA).balanceOf(address(this));
        // Lottery time, but for real this time though
        if (_pot > winAmount) {
            return true;
        }
        return false;
    }

    function randomWinner() internal view returns(address){
        uint256 _randomWinner = random(_countUsers, w_rt);
        address _winnerAddress = getUserAtIndex(_randomWinner);
        return _winnerAddress;
    }

    function distributeLottery(address _winnerAddress, uint256 _balanceWinner) internal returns(bool) {
        if(_balanceWinner >= minBalance) {
            // Reward the winner handsomely.
            IBEP20(ADA).transfer(_winnerAddress, winAmount);

            emit LotteryWon(_winnerAddress, winAmount);
            uint256 winnings = userByAddress[_winnerAddress].totalWon;
            uint256 totalWon = winnings.add(winAmount);

            // Update user stats
            userByAddress[_winnerAddress].lastWon = winAmount;
            userByAddress[_winnerAddress].totalWon = totalWon;
            uint256 _index = userByAddress[_winnerAddress].index;
            userByIndex[_index].lastWon = winAmount;
            userByIndex[_index].totalWon = totalWon;

            // Update global stats
            addWinner(_winnerAddress, winAmount);
            _allWon = _allWon.add(winAmount);

            // Reset count and lottery pool.
            transactionsSinceLastLottery = 0;
            return true;
        } else {
            // No one won, and the next winner is going to be even richer!
            emit LotterySkipped(_winnerAddress, winAmount);
        }
        return false;
    }

    function isUser(address userAddress) private view returns (bool isIndeed) {
        return userByAddress[userAddress].tokenOwner;
    }

    function getUserAtIndex(uint256 index)
        private
        view
        returns (address userAddress)
    {
        return userByIndex[index].userAddress;
    }

    function getTotalWon(address userAddress)
        external
        view
        returns (uint256 totalWon)
    {
        return userByAddress[userAddress].totalWon;
    }

    function getLastWon(address userAddress)
        external
        view
        returns (uint256 lastWon)
    {
        return userByAddress[userAddress].lastWon;
    }

    function getTotalWon() external view returns (uint256) {
        return _allWon;
    }

    function addWinner(address userAddress, uint256 _lastWon) internal {
        lastWinner_value = _lastWon;
        lastWinner_address = userAddress;
    }

    function getLastWinner() external view returns (address, uint256) {
        return (lastWinner_address, lastWinner_value);
    }

    function insertUser(address userAddress, uint256 winnings)
        internal
        returns (uint256 index)
    {
        if (_isExcludedFromLottery[userAddress]) {
            return index;
        }

        userByAddress[userAddress] = userData(
            userAddress,
            winnings,
            winnings,
            _countUsers,
            true
        );
        userByIndex[_countUsers] = userData(
            userAddress,
            winnings,
            winnings,
            _countUsers,
            true
        );
        index = _countUsers;
        _countUsers += 1;

        return index;
    }
}

contract WINIPHONE is Ownable, IBEP20, SafeToken, LockToken, JackPot{
    using SafeMath for uint256;

    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    string constant _name = "Win An Iphone";
    string constant _symbol = "WINIPHONE";
    uint8 constant _decimals = 9;
    uint256 _totalSupply = 10000000000 * (10 ** _decimals);

    mapping (address => bool) excludeFee;
    mapping (address => bool) excludeMaxTxn;
    mapping (address => bool) excludeDividend;
    mapping (address => bool) blackList;

    uint256 public _maxTxAmount = _totalSupply;
    uint256 public buyAdaLimit = 1 * 10**18;

    uint256 lotteryFee = 300;
    uint256 reflectionFee = 800;
    uint256 marketingFee = 300;
    uint256 totalFee = lotteryFee.add(reflectionFee).add(marketingFee);
    uint256 feeDenominator = 10000;

    address public marketing;

    IDEXRouter public router;
    address pair;

    DividendDistributor distributor;
    uint256 distributorGas = 500000;

    bool public swapEnabled = true;
    bool public buyAdaEnable = true;
    uint256 public swapThreshold = _totalSupply / 5000; // 0.02%
    bool inSwap;
    
    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor () {
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        _allowances[address(this)][address(router)] = ~uint256(0);

        distributor = new DividendDistributor();

        address owner_ = msg.sender;

        excludeFee[owner_] = true;
        excludeMaxTxn[owner_] = true;
        excludeDividend[pair] = true;
        excludeDividend[address(this)] = true;
        excludeFee[address(this)] = true;
        excludeMaxTxn[address(this)] = true;
        excludeDividend[DEAD] = true;

        marketing = owner_;

        _balances[owner_] = _totalSupply;
        emit Transfer(address(0), owner_, _totalSupply);
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, ~uint256(0));
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != ~uint256(0)){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal open(sender, recipient) returns (bool) {
        require(!blackList[sender], "Address is blacklisted");

        if(inSwap){ return _basicTransfer(sender, recipient, amount); }
        
        checkTxLimit(sender, amount);

        if(canSwap()) {
            if(shouldSwapBack()){ swapBack(); }
            if(shouldBuyAda()) {buyAda();}
        }

        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        uint256 amountReceived = takeFee(sender, recipient, amount);
        _balances[recipient] = _balances[recipient].add(amountReceived);

        if(!excludeDividend[sender]){ try distributor.setShare(sender, _balances[sender]) {} catch {} }
        if(!excludeDividend[recipient]){ try distributor.setShare(recipient, _balances[recipient]) {} catch {} }

        try distributor.process(distributorGas) {} catch {}
        _handleLottery(recipient);
        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _handleLottery(address recipient) internal returns(bool){
        if(_checkLottery(recipient)) {
            address winner = randomWinner();
            return distributeLottery(winner, balanceOf(winner));
        }
        return false;
    }

    function canSwap() internal view returns (bool) {
        return msg.sender != pair && !inSwap;
    }

    function shouldBuyAda() internal view returns (bool) {
        return buyAdaEnable
        && address(this).balance >= uint256(1 * 10**18);
    }
    
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount <= _maxTxAmount || excludeMaxTxn[sender], "TX Limit Exceeded");
    }

    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        if (excludeFee[sender] || excludeFee[recipient]) return amount;

        uint256 feeAmount = amount.mul(totalFee).div(feeDenominator);
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    function swapBack() internal swapping {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WBNB;

        uint256 balanceBefore = address(this).balance;

        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapThreshold,
            0,
            path,
            address(this),
            block.timestamp
        ) {
            uint256 amountBNB = address(this).balance.sub(balanceBefore);
            uint256 amountBNBReflection = amountBNB.mul(reflectionFee).div(totalFee);
            uint256 amountBNBMarketing = amountBNB.mul(marketingFee).div(totalFee);

            try distributor.deposit{value: amountBNBReflection}() {} catch {}
            payable(marketing).call{value: amountBNBMarketing, gas: 30000}("");
            emit SwapBackSuccess(swapThreshold);
        } catch Error(string memory e) {
            emit SwapBackFailed(string(abi.encodePacked("SwapBack failed with error ", e)));
        } catch {
            emit SwapBackFailed("SwapBack failed without an error message from pancakeSwap");
        }
    }

    function buyAda() private swapping {
        uint256 amount = address(this).balance;
        if (amount > buyAdaLimit) {amount = buyAdaLimit;}

        if (amount > 0) {
            swapBnbForAda(amount);
        }
    }

    function swapBnbForAda(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(ADA);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            address(this),
            block.timestamp
        );

        emit SwapBNBForTokens(amount, path);
    }


    function setTxLimit(uint256 amount) external onlyOwner {
        _maxTxAmount = amount;
    }

    function setExcludeDividend(address holder, bool exempt) external onlyOwner {
        require(holder != address(this) && holder != pair);
        excludeDividend[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);
        }else{
            distributor.setShare(holder, _balances[holder]);
        }
    }

    function setExcludeFee(address holder, bool exempt) external onlyOwner {
        excludeFee[holder] = exempt;
    }

    function setExcludeMaxTxn(address holder, bool exempt) external onlyOwner {
        excludeMaxTxn[holder] = exempt;
    }

    function setFees(uint256 _lotteryFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _feeDenominator) external onlyOwner {
        lotteryFee = _lotteryFee;
        reflectionFee = _reflectionFee;
        marketingFee = _marketingFee;
        totalFee = _lotteryFee.add(_reflectionFee).add(_marketingFee);
        feeDenominator = _feeDenominator;
        require(totalFee <= feeDenominator / 5, "Invalid Fee");
    }

    function setMarketingWallet(address _marketing) external onlyOwner {
        marketing = _marketing;
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount, uint256 _buyAdaLimit) external onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _amount;
        buyAdaLimit = _buyAdaLimit;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minimumTokenBalanceForDividends) external onlyOwner {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution, _minimumTokenBalanceForDividends);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas <= 1000000);
        distributorGas = gas;
    }
    
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function claimDividend() external {
        distributor.claimDividend();
    }

    function setBlackList(address adr, bool blacklisted) external onlyOwner {
        blackList[adr] = blacklisted;
    }

    event SwapBackSuccess(uint256 amount);
    event SwapBackFailed(string message);
    event SwapBNBForTokens(uint256 amount, address[] path);
}
