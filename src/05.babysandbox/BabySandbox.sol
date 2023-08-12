pragma solidity 0.7.0;

contract BabySandbox {

    function run(address code) external payable {
        assembly {
            // 如果调用者是合约自己(msg.sender == executing contract)
            // 第一次我们调用的时候，合约不会自己调用自己，因此不会进入
            if eq(caller(), address()) {
                switch delegatecall(gas(), code, 0x00, 0x00, 0x00, 0x00)
                    // delegatecall需要返回true，否则调用revert
                    case 0 {
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    case 1 {
                        returndatacopy(0x00, 0x00, returndatasize())
                        return(0x00, returndatasize())
                    }
            }
            
            // 保证有足够的gas
            if lt(gas(), 0xf000) {
                revert(0x00, 0x00)
            }
            
            // 从calldata加载数据到memory
            calldatacopy(0x00, 0x00, calldatasize())
            
            // 运行staticcall
            // 如果代码是恶意的（尝试修改本合约的状态变量）则revert。这里是进入到本合约的run()
            if iszero(staticcall(0x4000, address(), 0, calldatasize(), 0, 0)) {
                revert(0x00, 0x00)
            }
            
            // 前面执行完，可以判断代码不是恶意的了，然后执行call
            switch call(0x4000, address(), 0, 0, calldatasize(), 0, 0)
                case 0 {
                    returndatacopy(0x00, 0x00, returndatasize())
                    // revert(0x00, returndatasize())
                }
                case 1 {
                    returndatacopy(0x00, 0x00, returndatasize())
                    return(0x00, returndatasize())
                }
        }
    }
}
