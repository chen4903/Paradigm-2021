pragma solidity 0.5.12;

import "./Wallet.sol";

contract WETH9 is ERC20Like {
    function deposit() public payable;
}

contract Setup {
    // 为了复现，我将下面的代码修改一下，但是效果是差不多一样的
    // WETH9 public constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    WETH9 public WETH ;

    uint public constant WANT = 50 ether;

    Wallet public wallet;

    constructor(address _addr) public payable {
        require(msg.value == WANT);
        WETH = WETH9(_addr);

        address tokenModule = address(new TokenModule());

        wallet = new Wallet();
        // wallet 批准 tokenModule 合约
        wallet.allowModule(tokenModule);

        // 本合约在WETH合约拥有50ETH
        WETH.deposit.value(msg.value)();
        // wallet可以操作本合约在WETH的50ETH
        WETH.approve(address(wallet), uint(-1));

        // wallet在WETH合约拥有50ETH
        wallet.execModule(tokenModule, abi.encodeWithSelector(TokenModule(0x00).deposit.selector, WETH, address(this), msg.value));
    }

    // 任务：将本合约的余额从0修改为50
    function isSolved() public view returns (bool) {
        return WETH.balanceOf(address(this)) == WANT;
    }
}