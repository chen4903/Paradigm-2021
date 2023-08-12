pragma solidity 0.8.0;

// a simple overcollateralized loan bank which accepts WETH as collateral and a
// token for borrowing. 0% APRs
contract Broker {
    IUniswapV2Pair public pair;

    // 为了复现，修改一点代码，但是效果是差不多一样的
    // WETH9 public constant weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    WETH9 public immutable weth;

    ERC20Like public token;

    mapping(address => uint256) public deposited;
    mapping(address => uint256) public debt;

    constructor (IUniswapV2Pair _pair, ERC20Like _token,address _weth) {
        pair = _pair;
        token = _token;
        weth = WETH9(_weth);
    }

    // 计算价格
    function rate() public view returns (uint256) {
        // _reserve0：WETH
        // _reserve1：Ltoken
        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();
        // 因为复现的原因，WETH的地址不一样，排布就不一样，因此需要修改顺序
        // uint256 _rate = uint256(_reserve0 / _reserve1);
        uint256 _rate = uint256(_reserve1 / _reserve0);
        // 得到：1个WETH价值多少Ltoken
        return _rate;
    }

    // 阈值：得到的是你质押WETH价值的Ltoken数量
    function safeDebt(address user) public view returns (uint256) {
        return deposited[user] * rate() * 2 / 3;
    }

    // 借款
    function borrow(uint256 amount) public {
        debt[msg.sender] += amount;
        // 保证借了之后仍然处于健康状态，不会被清算
        require(safeDebt(msg.sender) >= debt[msg.sender], "err: undercollateralized");
        token.transfer(msg.sender, amount);
    }

    // 还款
    function repay(uint256 amount) public {
        debt[msg.sender] -= amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    // 清算
    function liquidate(address user, uint256 amount) public returns (uint256) {
        // 负债大于质押，可清算
        require(safeDebt(user) <= debt[user], "err: overcollateralized");
        // 清算借款人的一定数量amount金额，用token清算
        debt[user] -= amount;
        token.transferFrom(msg.sender, address(this), amount);
        
        // 清算人得到WETH
        // 实际清算的WETH数量 * WETH价格 = 清算的WETH数量
        // 那么，amount设置为：想要清算的数目n * rate() = y
        // amount / rate() = y / rate() = n * rate() / rate() = n
        // 这样就想扣除Broker多少WETH就扣除多少(n)
        uint256 collateralValueRepaid = amount / rate();
        weth.transfer(msg.sender, collateralValueRepaid);
        return collateralValueRepaid;
    }

    // 存款/质押：WETH
    function deposit(uint256 amount) public {
        deposited[msg.sender] += amount;
        weth.transferFrom(msg.sender, address(this), amount);
    }

    // 取款
    function withdraw(uint256 amount) public {
        deposited[msg.sender] -= amount;
        // 取款之后不能低于健康因子
        require(safeDebt(msg.sender) >= debt[msg.sender], "err: undercollateralized");

        weth.transfer(msg.sender, amount);
    }
}

interface IUniswapV2Pair {
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface ERC20Like {
    function transfer(address dst, uint qty) external returns (bool);
    function transferFrom(address src, address dst, uint qty) external returns (bool);
    function approve(address dst, uint qty) external returns (bool);
    
    function balanceOf(address who) external view returns (uint);
}

interface WETH9 is ERC20Like {
    function deposit() external payable;
}