pragma solidity 0.8.0;

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

interface Protocol {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function underlying() external view returns (ERC20Like);
    function balanceUnderlying() external view returns (uint256);
    function rate() external view returns (uint256);
}

// accepts multiple tokens and forwards them to banking protocols compliant to an interface
contract YieldAggregator {
    address public owner;
    address public harvester;

    mapping (address => uint256) public poolTokens;

    constructor() {
        owner = msg.sender;
    }

    // 存款：将非WETH存入此合约，将WETH转存protocol合约
    function deposit(Protocol protocol, address[] memory tokens, uint256[] memory amounts) public {
        // 获得protocol合约的WETH余额
        uint256 balanceBefore = protocol.balanceUnderlying();
        // 如果msg.sender存入WETH，则此合约会转存到protocol，
        // 其他任何token都存入到此合约
        for (uint256 i= 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            // msg.sender将自己的资产转到此合约，调用之前记得先approve
            ERC20Like(token).transferFrom(msg.sender, address(this), amount);

            // 授权：token(此合约 => protocol , amount)
            ERC20Like(token).approve(address(protocol), 0); // 纯纯浪费gas
            ERC20Like(token).approve(address(protocol), amount);

            // 所有代币都尝试转存到protocol，如果不是WETH，则会报错，
            // 但是交易不会revert，并且收回授权
            try protocol.mint(amount) {

             } catch { 
                ERC20Like(token).approve(address(protocol), 0);
            }
        }

        // 如果转存了WETH，则在本合约记录
        uint256 balanceAfter = protocol.balanceUnderlying();
        uint256 diff = balanceAfter - balanceBefore;
        poolTokens[msg.sender] += diff;
    }

    // 取款
    function withdraw(Protocol protocol, address[] memory tokens, uint256[] memory amounts) public {
        uint256 balanceBefore = protocol.balanceUnderlying();
        for (uint256 i= 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            // 取款任何token，都会拿回WETH
            protocol.burn(amount);
            // 然后将某种代币发回给用户
            ERC20Like(token).transfer(msg.sender, amount);
        }
        uint256 balanceAfter = protocol.balanceUnderlying();

        uint256 diff = balanceBefore - balanceAfter;
        // 如果有在protocol取出WETH，则记录
        poolTokens[msg.sender] -= diff;
    }
}
