// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "../../src/01.hello/Setup.sol";

contract attackTest is Test {
    Setup public level;
    Hello public hello;

    function setUp() public {
        level = new Setup();
    }

    function test_isComplete() public{
        hello = level.hello();
        hello.solve();
        assertEq(level.isSolved(), true);
    }

}
