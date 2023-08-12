pragma solidity 0.8.0;

interface IWETH9{
    function deposit() external payable;
    function decimals() external view returns(uint8);
    function transfer(address, uint) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns(uint256);
}

interface Iu_erc20{
    function DOMAIN_SEPARATOR() external view returns(bytes32);
}

interface Iu_factory{
    function DOMAIN_SEPARATOR() external view returns(bytes32);
}

interface Iu_router{
    function swapExactTokensForTokens(uint256, uint256, address[] calldata ,address , uint256 ) external;
    function getAmountOut(uint, uint, uint) external pure returns (uint );
}

interface IPair{
    function getReserves() external view returns (uint112, uint112, uint32);
}