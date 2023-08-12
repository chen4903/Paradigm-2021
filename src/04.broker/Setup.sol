pragma solidity 0.8.0;

import "./Broker.sol";

contract Token {
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public dropped;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply = 1_000_000 ether;
    uint256 public AMT = totalSupply / 100_000; // 10

    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }

    function approve(address to, uint256 amount) public returns (bool) {
        allowance[msg.sender][to] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (from != msg.sender) {
            allowance[from][to] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function airdrop() public {
        require(!dropped[msg.sender], "err: only once");
        dropped[msg.sender] = true;
        balanceOf[msg.sender] += AMT;
        totalSupply += AMT;
    }
}

contract Setup {
    // 为了复现，修改一点代码，但是效果是差不多一样的
    // WETH9 public constant weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // IUniswapV2Factory public constant factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    WETH9 public weth;
    IUniswapV2Factory public factory;

    Token public token;
    IUniswapV2Pair public pair;
    Broker public broker;

    uint256 constant DECIMALS = 1 ether;
    uint256 totalBefore;

    // create and bootstrap the token/weth pool for borrowing against WETH
    constructor(address _weth, address _factory) payable {
        // 本合约拥有 50 ether
        require(msg.value == 50 ether);

        // 为了复现，修改一点代码，但是效果是差不多一样的
        weth = WETH9(_weth);
        factory = IUniswapV2Factory(_factory);

        // 本合约在WETH合约拥有 50 ether
        weth.deposit{value: msg.value}();

        // 新建Ltoken合约
        token = new Token();
        // 创建交易对池子：WETH 和 Ltoken
        pair = IUniswapV2Pair(factory.createPair(address(weth), address(token)));
        // 创建Broker
        broker = new Broker(pair, ERC20Like(address(token)),address(weth));
        // 本合约将一半的Ltoken转给broker
        token.transfer(address(broker), 500_000 * DECIMALS);

        // 本合约向池子转25WETH
        weth.transfer(address(pair), 25 ether);
        // 本合约向池子转2500_000个Ltoken
        token.transfer(address(pair), 500_000 * DECIMALS);
        // 此时池子的比例：500_000：25 = 20_000: 1

        // 因为本合约提供了流动性，因此mint LPtoken给本合约
        pair.mint(address(this));

        // 本合约授权：broken可以操作本合约在WETH的资产
        weth.approve(address(broker), type(uint256).max);
        // 本合约在broker中存款25ether
        broker.deposit(25 ether);
        // 本合约在broker中取款250_000数量的Ltoken
        broker.borrow(250_000 * DECIMALS);

        // 总资产：broker的WETH余额 + broker在Ltoken的安全余额
        totalBefore = weth.balanceOf(address(broker)) + token.balanceOf(address(broker)) / broker.rate();
    }

    // 任务：使得broker合约的WETH余额小于5 ether
    function isSolved() public view returns (bool) {
        return weth.balanceOf(address(broker)) < 5 ether;
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
