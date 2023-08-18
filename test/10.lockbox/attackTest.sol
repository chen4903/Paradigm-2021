// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "./helper_setupBytecode.sol";
import "./interface.sol";

contract attackTest is Test {

    ISetup public level;
    IEntrypoint public entrypoint;

    function setUp() public {
        // 初始化题目
        level = ISetup(deploySetup());
        vm.label(address(level), "level");
        entrypoint = IEntrypoint(level.entrypoint());
        vm.label(address(entrypoint), "entrypoint");

        // 在foundry中，每次测试的结果都是一样的，为了方便看trace，我们定下标签
        vm.label(address(0x044AB9df2D2779933d10dfaF082540c0955B0307), "stage5");
        vm.label(address(0xcAF4fdfB21455c48cBf8586eb02E4c09B4CE9B37), "stage4");
        vm.label(address(0x2492Df72782081982f6344c92BDa4cB8e60eaA3E), "stage3");
        vm.label(address(0x7f0Fd12Ce1780616AAd60aeF535ad5F8353a49d1), "stage2");
        vm.label(address(0x41C3c259514f88211c4CA2fd805A93F8F9A57504), "stage1");
    }

    function test_isComplete() public{
        bytes4 guess = bytes4(blockhash(block.number - 1));

        bytes memory data = abi.encodePacked(
        	bytes4(0xe0d20f73),
            guess, bytes28(0x0000000000000000000000000000000000000000000000000000ff1c),
            bytes32(0x10d188c245dadc6b749cc5dedc56093db37a555fb80cacbc386f899f0de55468),
            bytes32(0x53f5beb75699a068c70adbf9d545de94ec2511fe56862363799f44a700e62769),
            bytes32(0xe201a979a73f6a2947c212ebbed36f5d85b35629db25dfd9441d562a1c6ca896),
            bytes32(0xe201a979a73f6a2947c212ebbed36f5d85b35629db25dfd9441d562a1c6ca898),
            bytes32(0x10d188c245dadc6b749cc5dedc56093db37a555fb80cacbc386f899f0de55468),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000003)
        );

        // 不能直接调用solve(), 因为这样就没有后面的calldata了，我们要发送原始的calldata
        // 可以用ethersjs来发送，也可以在solidity中用内联汇编

        uint size = data.length;
        address entry = address(entrypoint);
        assembly{
            switch call(gas(), entry, 0, add(data,0x20), size, 0, 0)
            case 0 {
                   returndatacopy(0x00,0x00,returndatasize())
                   revert(0, returndatasize()) 
            }
        }

        // 查看是否完成题目
        assertEq(level.isSolved(),true);

    }

    function deploySetup() public returns (address addr) {
        bytes memory bytecode = BYTECODE;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}

