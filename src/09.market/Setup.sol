pragma solidity 0.7.0;

import "./Market.sol";

contract Setup {
    EternalStorageAPI public eternalStorage; // 存储
    CryptoCollectibles public token; // 业务逻辑
    CryptoCollectiblesMarket public market; // 市场
    
    constructor() payable {
        require(msg.value == 50 ether);
        
        // deploy our contracts
        // 存储
        eternalStorage = EternalStorageAPI(address(new EternalStorage(address(this))));
        // 逻辑
        token = new CryptoCollectibles();
        
        // 逻辑合约初始化：成为存储合约的owner
        eternalStorage.transferOwnership(address(token));
        token.setEternalStorage(eternalStorage);
        
        // 市场：mint一次至少要1 ether，手续费千分之一
        market = new CryptoCollectiblesMarket(token, 1 ether, 1000);
        // 逻辑合约让市场合约成为minter
        token.setMinter(address(market), true);
        
        // mint 4 founders tokens
        uint tokenCost = 5 ether;
        for (uint i = 0; i < 4; i++) {
            // 给某4不知道的地址预挖4个token
            market.mintCollectibleFor{value: tokenCost}(address(bytes20(keccak256(abi.encodePacked(address(this), i)))));
            tokenCost += 5 ether;
        } // 5,10,15,20
    }
    
    // 市场合约的余额为0
    function isSolved() external view returns (bool) {
        return address(market).balance == 0;
    }
}
