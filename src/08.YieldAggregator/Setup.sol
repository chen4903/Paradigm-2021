pragma solidity 0.8.0;

import "./YieldAggregator.sol";

interface WETH9 is ERC20Like {
    function deposit() external payable;
}

contract MiniBank is Protocol {
    // 标的资产：WETH
    // 为了复现，修改一下
    ERC20Like public override underlying;

    mapping (address => uint256) public balanceOf;
    uint256 public totalSupply;

    constructor(address _address) {
        underlying = ERC20Like(_address);
    }

    // 存款：存入标的资产，然后记录
    function mint(uint256 amount) public override {
        require(underlying.transferFrom(msg.sender, address(this), amount));
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    // 取款
    function burn(uint256 amount) public override {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        require(underlying.transfer(msg.sender, amount));
    }

    // 本合约的标的资产余额
    function balanceUnderlying() public override view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    function rate() public override view returns (uint256) {
        return 1;
    }
}

contract Setup {
    YieldAggregator public aggregator;
    MiniBank public bank;
    // 为了复现，修改一下
    WETH9 public weth;

    constructor(address _addr) payable {
        weth = WETH9(_addr);
        require(msg.value == 100 ether);
        // 为了复现，修改一下
        bank = new MiniBank(address(weth));

        aggregator = new YieldAggregator();

        // 存入100ETH，此合约获得100WETH
        weth.deposit{value: msg.value}();
        // WETH：此合约授权给aggregator最大值
        weth.approve(address(aggregator), type(uint256).max);

        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);

        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 50 ether;

        // 此合约向aggregator存入50WETH
        aggregator.deposit(Protocol(address(bank)), _tokens, _amounts);
    }

    function isSolved() public view returns (bool) {
        return weth.balanceOf(address(aggregator)) == 0 && weth.balanceOf(address(bank)) == 0;
    }
}
