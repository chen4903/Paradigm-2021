pragma solidity 0.7.0;

import "./EternalStorage.sol";

contract CryptoCollectibles {
    address public owner;
    EternalStorageAPI public eternalStorage;
    
    mapping(address => bool) public minters;
    uint public tokenIdSalt;
    
    constructor() {
        owner = msg.sender;
        minters[owner] = true;
    }
    
    // 设置谁是minter
    function setMinter(address newMinter, bool isMinter) external {
        require(msg.sender == owner, "setMinter/not-owner");
        
        minters[newMinter] = isMinter;
    }
    
    // 转让存储合约的所有权，只有owner可以修改。但owner没有转让机制
    function setEternalStorage(EternalStorageAPI eternalStorage_) external {
        require(msg.sender == owner, "setEternalStorage/not-owner");
        
        eternalStorage = eternalStorage_;
        eternalStorage.acceptOwnership();
    }
    
    function mint(address tokenOwner) external returns (bytes32) {
        // 只有minter才能mint
        require(minters[msg.sender], "mint/not-minter");
        
        // 计算出新的token的ID，然后mint
        bytes32 tokenId = keccak256(abi.encodePacked(address(this), tokenIdSalt++));
        eternalStorage.mint(tokenId, "My First Collectible", tokenOwner);
        return tokenId;
    }
    
    function transfer(bytes32 tokenId, address to) external {
        require(msg.sender == eternalStorage.getOwner(tokenId), "transfer/not-owner");
        
        eternalStorage.updateOwner(tokenId, to);
        eternalStorage.updateApproval(tokenId, address(0x00));
    }
    
    function approve(bytes32 tokenId, address authorized) external {
        require(msg.sender == eternalStorage.getOwner(tokenId), "approve/not-owner");
        
        eternalStorage.updateApproval(tokenId, authorized);
    }
    
    function transferFrom(bytes32 tokenId, address from, address to) external {
        require(from == eternalStorage.getOwner(tokenId), "transferFrom/not-owner");
        require(msg.sender == eternalStorage.getApproval(tokenId), "transferFrom/not-approved");
        
        eternalStorage.updateOwner(tokenId, to);
        eternalStorage.updateApproval(tokenId, address(0x00));
    }

    function getTokenInfo(bytes32 tokenId) external view returns (bytes32, address, address, address) {
        return (
            eternalStorage.getName(tokenId),
            eternalStorage.getOwner(tokenId),
            eternalStorage.getApproval(tokenId),
            eternalStorage.getMetadata(tokenId)
        );
    }
    
    // 返回的是metadata合约的bytecode
    function getTokenMetadata(bytes32 tokenId) external view returns (bytes memory) {
        // TokenInfo中的metadata属性，是一个地址
        address metadata = eternalStorage.getMetadata(tokenId);
        if (metadata == address(0x00)) {
            return new bytes(0);
        }
        
        bytes memory data;
        assembly {
            // 获得空闲指针的位置
            data := mload(0x40)
            // 空闲的memory写入metadata合约的代码长度大小
            mstore(data, extcodesize(metadata))
            // 将metadata合约的bytecode拷贝到内存
            extcodecopy(metadata, add(data, 0x20), 0, mload(data))
        }
        return data;
    }
    
}

contract CryptoCollectiblesMarket {
    address payable public owner;
    CryptoCollectibles public cryptoCollectibles;
    
    mapping(bytes32 => uint) tokenPrices;
    uint public minMintPrice;
    uint public mintFeeBps;
    uint public feeCollected;
    
    constructor(CryptoCollectibles cryptoCollectibles_, uint minMintPrice_, uint mintFeeBps_) {
        owner = msg.sender;
        cryptoCollectibles = cryptoCollectibles_;
        // mint一次至少要1 ether，手续费千分之一
        minMintPrice = minMintPrice_;
        mintFeeBps = mintFeeBps_;
    }
    
    // 买
    function buyCollectible(bytes32 tokenId) public payable {
        require(tokenPrices[tokenId] > 0, "buyCollectible/not-listed");
        
        (, address tokenOwner, , ) = cryptoCollectibles.getTokenInfo(tokenId);
        // 此合约必须拥有这个token
        require(tokenOwner == address(this), "buyCollectible/already-sold");
        
        // 发钱到这个合约
        require(msg.value == tokenPrices[tokenId], "buyCollectible/bad-value");
        
        // 转让token的所有权
        cryptoCollectibles.transfer(tokenId, msg.sender);
    }
    
    // 卖
    function sellCollectible(bytes32 tokenId) public payable {
        require(tokenPrices[tokenId] > 0, "sellCollectible/not-listed");
        
        (, address tokenOwner, address approved, ) = cryptoCollectibles.getTokenInfo(tokenId);
        require(msg.sender == tokenOwner, "sellCollectible/not-owner");
        // 卖之前需要approve给此合约
        require(approved == address(this), "sellCollectible/not-approved");
        
        cryptoCollectibles.transferFrom(tokenId, msg.sender, address(this));
        
        // 然后此合约转钱
        msg.sender.transfer(tokenPrices[tokenId]);
    }
    
    // mint
    function mintCollectible() public payable returns (bytes32) {
        return mintCollectibleFor(msg.sender);
    }
    
    // mint
    function mintCollectibleFor(address who) public payable returns (bytes32) {
        uint sentValue = msg.value;
        // 似乎有四舍五入的问题？
        uint mintPrice = sentValue * 10000 / (10000 + mintFeeBps);
        
        require(mintPrice >= minMintPrice, "mintCollectible/bad-value");
        
        bytes32 tokenId = cryptoCollectibles.mint(who);
        tokenPrices[tokenId] = mintPrice;
        feeCollected += sentValue - mintPrice;
        return tokenId;
    }
    
    // owner提取手续费
    function withdrawFee() public {
        require(msg.sender == owner, "withdrawFee/not-owner");
        
        owner.transfer(feeCollected);
        feeCollected = 0;
    }
}
