// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

contract attacker02 {
    // immutable会在合约初始化的时候完成赋值
    address immutable exploit;

    constructor() {
        exploit = address(this);
    }

    event Ping();
    function stateChangingAction() external {
        emit Ping();
    }

    fallback() external {
        (bool success, ) = exploit.call(abi.encodeWithSelector(this.stateChangingAction.selector));
        if (success) {
            selfdestruct(payable(address(0x0)));
        }
    }
    // 不能有receive()，否则不会走fallback()

}
