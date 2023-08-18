pragma solidity 0.4.24;

import "./Bank.sol";

contract WETH9 is ERC20Like {
    function deposit() public payable;
}

contract Setup {
    // 复现需要，修改WETH地址
    WETH9 public weth;
    Bank public bank;
    
    constructor(address _weth) public payable {
        weth = WETH9(_weth);
        require(msg.value == 50 ether);
        
        bank = new Bank();
        
        // 此合约获得50WETH
        weth.deposit.value(msg.value)();
        // WETH授权：此合约授权bank最大金额
        weth.approve(address(bank), uint(-1));
        // 此合约在bank新建一个account，存储WETH，金额为50WETH
        bank.depositToken(0, address(weth), weth.balanceOf(address(this)));
    }
    
    // 让bank的WETH数量归零
    function isSolved() external view returns (bool) {
        return weth.balanceOf(address(bank)) == 0;
    }
}
