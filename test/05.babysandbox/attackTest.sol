// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2; // https://github.com/foundry-rs/foundry/issues/4376

import "forge-std/Test.sol";
import "../../src/05.babysandbox/Setup.sol";
import "./attacker01.sol";
import "./attacker02.sol";

contract attackTest is Test {
    Setup public level;
    BabySandbox babySandbox;

    function setUp() public {
        // 初始化题目
        level = new Setup();
        babySandbox = level.sandbox();

        // 因为foundry只有在一次调用结束的时候，才会更新账户的代码长度信息,网址：
        // https://github.com/foundry-rs/foundry/issues/1543
        // 因此我们借助在setup中调用，然后在test_isComplete()中就可以检测到是否完成

        // 解法1
        attacker01 hack = new attacker01();
        vm.label(address(hack), "attacker01");
        babySandbox.run(address(hack));
        //解法2
        // attacker02 hack = new attacker02();
        // vm.label(address(hack), "attacker02");
        // babySandbox.run(address(hack));
    }

    function test_isComplete() public{
        assertEq(level.isSolved(), true);
    }

}