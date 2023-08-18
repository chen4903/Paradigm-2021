pragma solidity 0.8.0;

interface ISetup{
    function entrypoint() external view returns (address);
    function isSolved() external view returns (bool);
}

interface IEntrypoint{
    function solved() external view returns (bool);
    function next() external view returns (address);
    function getSelector() external view returns (bytes4);
    function solve(bytes4) external;
}