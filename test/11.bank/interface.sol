pragma solidity 0.8.0;

interface IBank {
    function depositToken(
        uint256 accountId,
        address token,
        uint256 amount
    ) external;

    function getAccountInfo(uint256 accountId)
        external
        view
        returns (string memory, uint256);

    function setAccountName(uint256 accountId, string memory name) external;

    function getAccountBalance(uint256 accountId, address token)
        external
        view
        returns (uint256);

    function withdrawToken(
        uint256 accountId,
        address token,
        uint256 amount
    ) external;

    function closeLastAccount() external;

    function acceptOwnership() external;

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function transferOwnership(address newOwner) external;
}

interface IWETH9{
    function deposit() external payable;
    function decimals() external view returns(uint8);
    function transfer(address, uint) external returns (bool);
    function balanceOf(address)external view returns(uint256);
    function approve(address,uint256) external payable returns (bool);
}

interface ISetup{
    function bank() external view returns(address);
    function weth() external view returns(address);
    function isSolved() external view returns(bool);
}