pragma solidity ^0.8.0;

import "./Farmer.sol";

contract Setup {
    uint256 expectedBalance;

    CompDaiFarmer public farmer;
    CompFaucet public faucet;

    // 为了复现，我们修改一点内容
    // ERC20Like public constant COMP = ERC20Like(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    // ERC20Like public constant DAI = ERC20Like(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // CERC20Like public constant CDAI = CERC20Like(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    // UniRouter public constant ROUTER = UniRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    // WETH9 public constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ERC20Like public COMP ;
    ERC20Like public DAI;
    CERC20Like public CDAI;
    UniRouter public ROUTER;
    WETH9 public WETH;

    constructor(address _COMP, address _DAI, address _CDAI, address _ROUTER, address _WETH) payable { // 假设存50ether
        COMP = ERC20Like(_COMP);
        DAI = ERC20Like(_DAI);
        CDAI = CERC20Like(_CDAI);
        ROUTER = UniRouter(_ROUTER);
        WETH = WETH9(_WETH);

        // 本合约存ETH，获得WETH
        WETH.deposit{value: msg.value}();
        // 本合约授权给router合约所有金额
        WETH.approve(address(ROUTER), type(uint256).max);

        // deploy
        // 为了复现，我们修改一点内容
        // farmer = new CompDaiFarmer();
        // faucet = new CompFaucet(address(farmer));
        farmer = new CompDaiFarmer(address(COMP), address(DAI), address(CDAI), address(ROUTER), address(WETH));
        faucet = new CompFaucet(address(farmer), address(COMP));

        farmer.setComp(address(faucet));

        // swap：将WETH换成COMP
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(COMP);
        ROUTER.swapExactTokensForTokens(
            50 ether,
            0,
            path,
            address(this),
            block.timestamp + 1800
        );
        // 将本合约中的所有COMP发送给faucet
        uint256 compBalance = COMP.balanceOf(address(this));
        COMP.transfer(address(faucet), compBalance);
        // expectedBalance = farmer的的所有DAI + farmer可获得：faucet的COMP价值DAI的数量
        expectedBalance = DAI.balanceOf(address(farmer)) + farmer.peekYield();
    }

    function isSolved() public view returns (bool) {
        return COMP.balanceOf(address(faucet)) == 0 &&
            COMP.balanceOf(address(farmer)) == 0 &&
            DAI.balanceOf(address(farmer)) < expectedBalance;
    }
}
