pragma solidity ^0.8.0;

interface IComptroller {
    function claimComp(address holder, address[] calldata cTokens) external;
    function claimableComp() external view returns (uint256);

}

interface ERC20Like {
    function transfer(address dst, uint256 qty) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 qty
    ) external returns (bool);

    function balanceOf(address who) external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

}

interface WETH9 is ERC20Like {
    function deposit() external payable;
}

interface CERC20Like is ERC20Like {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
}

interface UniRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

     function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

// Mock contract to not have to deal with Compound's inflation in the challenge
// Assumes it gets funded somehow
contract CompFaucet {
    address owner;
    // 复现，修改题目，效果差不多一样
    // ERC20Like public constant comp = ERC20Like(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    ERC20Like public comp;

    constructor(address _owner, address _comp) {
        owner = _owner;
        comp = ERC20Like(_comp);
    }

    // owner获得本合约中的所有COMP
    function claimComp(address, address[] calldata) external {
        comp.transfer(owner, comp.balanceOf(address(this)));
    }

    // 查看合约的COMP余额
    function claimableComp() public view returns (uint256) {
        return comp.balanceOf(address(this));
    }
}

contract CompDaiFarmer {
    address public owner = msg.sender;
    address public harvester = msg.sender;

    // 复现，修改题目，效果差不多一样
    // ERC20Like public constant dai = ERC20Like(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // UniRouter public constant router = UniRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    // WETH9 public constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // CERC20Like public constant CDAI = CERC20Like(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    // ERC20Like public constant COMP = ERC20Like(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    ERC20Like public COMP ;
    ERC20Like public dai;
    CERC20Like public CDAI;
    UniRouter public router;
    WETH9 public WETH;

    IComptroller public comptroller;

    constructor(address _COMP, address _DAI, address _CDAI, address _ROUTER, address _WETH){
        COMP = ERC20Like(_COMP);
        dai = ERC20Like(_DAI);
        CDAI = CERC20Like(_CDAI);
        router = UniRouter(_ROUTER);
        WETH = WETH9(_WETH);
    }

    
    mapping (address => uint256) deposits;
    
    // 查看comptroller合约的 COMP能换多少DAI
    function peekYield() public view returns (uint256) {
        uint256 claimableAmount = IComptroller(comptroller).claimableComp();
        // COMP => WETH => DAI
        address[] memory path = new address[](3);
        path[0] = address(COMP);
        path[1] = address(WETH);
        path[2] = address(dai);

        uint256[] memory amounts = router.getAmountsOut(claimableAmount, path);
        return amounts[2];
    }

    // 存款：DAI
    function deposit(uint256 amount) public {
        require(dai.transferFrom(msg.sender, address(this), amount));
        deposits[msg.sender] += amount;
    }

    // 取款：DAI
    function withdraw(uint256 amount) public {
        deposits[msg.sender] -= amount;
        require(dai.transfer(msg.sender, amount));
    }

    // 将本合约所有的DAI转为cDAI
    function mint() public {
        uint256 daiBalance = dai.balanceOf(address(this));
        dai.approve(address(CDAI), daiBalance);
        CDAI.mint(daiBalance);
    }

    // 取款：取回cDAI标的资产
    function redeemUnderlying(uint256 amount) public {
        require(msg.sender == owner || amount <= deposits[msg.sender], "cannot redeem more than your balance");
        CDAI.redeemUnderlying(amount);
    }

    // comptroller的owner获得comptroller合约的所有COMP
    function claim() public {
        address[] memory ctokens = new address[](1);
        ctokens[0] = address(CDAI);
        // 其实上面这两行代码一点用都没有

        IComptroller(comptroller).claimComp(address(this), ctokens);
    }

    // swap：将本合约中的所有COMP换成DAI
    function recycle() public returns (uint256) {
        address[] memory path = new address[](3);
        path[0] = address(COMP);
        path[1] = address(WETH);
        path[2] = address(dai);

        uint256 bal = COMP.balanceOf(address(this));
        COMP.approve(address(router), bal);

        uint256[] memory amts = router.swapExactTokensForTokens(
            bal,
            0,
            path,
            address(this),
            block.timestamp + 1800
        );

        return amts[2];
    }

    // owner获得所有的COMP，然后将COMP换成DAI
    function claimAndRecycle() public {
        require(msg.sender == harvester, "err/only harvester");
        claim();
        recycle();
    }

    // 权限变更：harvester
    function changeHarvester(address newHarvester) public {
        require(msg.sender == owner);
        harvester = newHarvester;
    }

    // 设置新的comproller
    function setComp(address _comptroller) public {
        require(msg.sender == owner);
        comptroller = IComptroller(_comptroller);
    }
}
