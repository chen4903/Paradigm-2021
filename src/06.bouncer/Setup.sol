pragma solidity 0.8.0;

import "./Bouncer.sol";

interface WETH9 is ERC20Like {
    function deposit() external payable;
}

contract Setup {
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    WETH9 public weth;
    Bouncer public bouncer;
    Party public party;

    constructor(address _addr) payable {
        // 复现题目，修改一点，但是效果是差不多的
        weth = WETH9(_addr);

        // 100 ether初始化
        require(msg.value == 100 ether);
        // 给bouncer 100 ether
        bouncer = new Bouncer{value: 50 ether}();

        // Setup合约在bouncer中注册将要存款 10 WETH
        bouncer.enter{value: 1 ether}(address(weth), 10 ether);
        // Setup合约在bouncer中注册将要存款 10 ether
        bouncer.enter{value: 1 ether}(ETH, 10 ether);

        // 初始化party
        party = new Party(bouncer);
    }

    // 任务：bouncer的ETH余额设置为0
    function isSolved() public view returns (bool) {
        return address(bouncer).balance == 0;
    }
}
