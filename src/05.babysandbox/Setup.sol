pragma solidity 0.7.0;

import "./BabySandbox.sol";

contract Setup {
    BabySandbox public sandbox;
    
    constructor() {
        sandbox = new BabySandbox();
    }
    
    // 任务：sandbox合约的代码长度为0，即销毁sandbox合约
    function isSolved() public view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(sload(sandbox.slot))
        }
        return size == 0;
    }
}
