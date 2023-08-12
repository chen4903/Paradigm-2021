pragma solidity 0.8.0;

interface IERC20Like {
    function approve(address dst, uint256 qty) external returns (bool);

    function balanceOf(address who) external view returns (uint256);

    function transfer(address dst, uint256 qty) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 qty
    ) external returns (bool);
}

interface ITokenModule {
    function deposit(
        address token,
        address from,
        uint256 amount
    ) external;

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external;
}

interface IWallet {
    function addOperator(address operator) external;

    function allowModule(address module) external;

    function disallowModule(address module) external;

    function execModule(address module, bytes memory data) external;

    function owner() external view returns (address);

    function removeOperator(address operator) external;
}

interface IWETH9{
    function deposit() external payable;
    function decimals() external view returns(uint8);
    function transfer(address, uint) external returns (bool);
}

interface ISetup{
    function wallet() external view returns(address);
    function isSolved() external view returns (bool);
}