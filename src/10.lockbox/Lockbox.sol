pragma solidity 0.4.24;

contract Stage {
    Stage public next;
    
    constructor(Stage next_) public {
        next = next_;
    }
    
    // 0x034899bc
    function getSelector() public view returns (bytes4); // 等待子类去实现
    
    modifier _() {
        _;
        
        assembly {
            // next_slot没有值，则为0，因此这一步是获得slot的值然后赋给next
            let next := sload(next_slot)
            if iszero(next) {
                return(0, 0)
            }

            /*   调用下一个合约的getSelector(),然后存储到内存，其实结果都是slove()的函数选择器，继续把第一次传入的参数写进内存   */
                // 调用Stage上的getSelector()函数，将结果存储在内存中
                // 从各个stage的实现来看，getSelector()的结果是slove()的函数选择器
                // 将getSelector()的函数选择器存储在内存位置0之后
            mstore(0x00, 0x034899bc00000000000000000000000000000000000000000000000000000000)
            // 调用下一个stage的getSelector()函数
                // gas()：此次交易剩余的gas
                // next：我们执行下一个stage合约的方法
                // 0：发送0 wei
                // 0：内存0位置作为argsOffset
                // 0x04：截取长度为4的长度
                // 0x00：将数据返回到内存的起始位置是0
                // 0x04：截取长度为4的返回数据
            // 返回值为true或者false位于栈顶，把它pop掉
            // 此时内存0x00~0x04是getSelector()的返回值，即slove()的函数选择器
            pop(call(gas(), next, 0, 0, 0x04, 0x00, 0x04))

            // 从位置0x04的calldata复制sub(calldatasize(), 0x04)字节到内存0x04的位置
            // sub(calldatasize(), 0x04)是指去除了函数选择器，实际参数的长度
            calldatacopy(0x04, 0x04, sub(calldatasize(), 0x04))



            /*  调用下一个Stage合约的slove()，参数是第一次调用时传入的 */
                // gas()：此次交易剩余的gas
                // next：我们执行下一个stage合约的方法
                // 0：发送 0 wei
                // 0：发送 0 wei
                // calldatasize()：calldata长度
                // 0：将数据返回到内存的起始位置是0
                // 0：截取长度为0的返回数据
            switch call(gas(), next, 0, 0, calldatasize(), 0, 0)
                // 如果调用失败，则REVERT
                case 0 {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                // 如果调用失败，则返回`返回数据的大小`
                case 1 {
                    returndatacopy(0x00, 0x00, returndatasize())
                    return(0x00, returndatasize())
                }
        }
    }
}

contract Entrypoint is Stage {
    bool public solved;

    constructor() public Stage(new Stage1()) {

    } 

    function getSelector() public view returns (bytes4) {
        return this.solve.selector; 
    }
    
    // 0xe0d20f73
    function solve(bytes4 guess) public _ {
        require(guess == bytes4(blockhash(block.number - 1)), "do you feel lucky?");
        solved = true;
    }
}

contract Stage1 is Stage {
    constructor() public Stage(new Stage2()) {

    }
    
    function getSelector() public view returns (bytes4) {
        return this.solve.selector; 
    }
    
    function solve(uint8 v, bytes32 r, bytes32 s) public _ {
        require(ecrecover(keccak256("stage1"), v, r, s) == 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf, "who are you?");
    }
}

contract Stage2 is Stage {
    constructor() public Stage(new Stage3()) {

    }
    
    function getSelector() public view returns (bytes4) {
        return this.solve.selector; 
    }
    
    function solve(uint16 a, uint16 b) public _ {
        require(a > 0 && b > 0 && a + b < a, "something doesn't add up");
    }
}

contract Stage3 is Stage {
    constructor() public Stage(new Stage4()) {

    }

    function getSelector() public view returns (bytes4) {
        return this.solve.selector; 
    }
    
    function solve(uint idx, uint[4] memory keys, uint[4] memory lock) public _ {
        require(keys[idx % 4] == lock[idx % 4], "key did not fit lock");
        
        for (uint i = 0; i < keys.length - 1; i++) {
            require(keys[i] < keys[i + 1], "out of order");
        }
        
        for (uint j = 0; j < keys.length; j++) {
            require((keys[j] - lock[j]) % 2 == 0, "this is a bit odd");
        }
    }
}

contract Stage4 is Stage {
    constructor() public Stage(new Stage5()) {

    }

    function getSelector() public view returns (bytes4) {
        return this.solve.selector; 
    }
    
    function solve(bytes32[6] choices, uint choice) public _ {
        require(choices[choice % 6] == keccak256(abi.encodePacked("choose")), "wrong choice!");
    }
}

contract Stage5 is Stage {
    constructor() public Stage(Stage(0x00)) {

    }
    function getSelector() public view returns (bytes4) {
        return this.solve.selector; 
    }
    
    function solve() public _ {
        require(msg.data.length < 256, "a little too long");
    }
}
