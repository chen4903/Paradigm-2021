pragma solidity 0.8.0;

interface IWETH9{
    function deposit() external payable;
    function decimals() external view returns(uint8);
    function transfer(address, uint) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns(uint256);
    function transferFrom( address src,address dst, uint256 qty ) external returns (bool);
}