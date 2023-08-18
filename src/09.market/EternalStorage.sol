pragma solidity 0.7.0;

interface EternalStorageAPI {
    // mint a new token with the given token id, display name, and owner
    // restricted to: token
    function mint(bytes32 tokenId, bytes32 name, address owner) external;
    
    // update the name of the given token
    // restricted to: token or token owner
    function updateName(bytes32 tokenId, bytes32 name) external;
    // update the owner of the given token
    // restricted to: token or token owner
    function updateOwner(bytes32 tokenId, address newOwner) external;
    // update the approved user of the given token
    // restricted to: token or token owner
    function updateApproval(bytes32 tokenId, address approved) external;
    // update the address which holds the metadata of the given token
    // restricted to: token or token owner
    function updateMetadata(bytes32 tokenId, address metadata) external;
    
    // get the name of the token
    function getName(bytes32 tokenId) external view returns (bytes32);
    // get the owner of the token
    function getOwner(bytes32 tokenId) external view returns (address);
    // get the approved user of the token
    function getApproval(bytes32 tokenId) external view returns (address);
    // get the metadata contract associated with the token
    function getMetadata(bytes32 tokenId) external view returns (address);
    
    // transfers ownership of this storage contract to a new owner
    // restricted to: token
    function transferOwnership(address newOwner) external;
    // accepts ownership of this storage contract
    function acceptOwnership() external;
}

contract EternalStorage {

    // slot0存储的是owner的地址
    constructor(address token) payable {
        assembly {
            sstore(0x00, token)
        }
    }
    
    /*
        Eternal storage implementation. Optimized for gas efficiency so it's written in assembly. Equivalent Solidity:
        
        mapping(bytes32 => TokenInfo) tokens;
        
        struct TokenInfo {
            bytes32 displayName;
            address owner;
            address approved;
            address metadata;
        }
    */
    fallback() external payable {
        assembly {
            // onlyOwner: 获取slot0的内容（owner的地址），跟msg.sender比较
            function ensureOwner() {
                let owner := sload(0x00)
                
                if iszero(eq(caller(), owner)) {
                    revert(0, 0)
                }
            }
            
            // onlyPendingOwner：获取slot1的内容（pendingOwner的地址），跟msg.sender比较
            function ensurePendingOwner() {
                let pendingOwner := sload(0x01)
                
                if iszero(eq(caller(), pendingOwner)) {
                    revert(0, 0)
                }
            }
            
            // 必须是owner或者token的所有者
            function ensureTokenOwner(tokenId) {
                // 获得owner的地址
                let owner := sload(0x00)
                // tokenId是TokenInfo的slot位置，+1表示向下一个slot（也就是增加32bytes），因为TokenInfo第二个属性才是owner
                let tokenOwner := sload(add(tokenId, 1))
                
                // 两者满足一个条件即可
                if iszero(or(
                    // 是不是owner
                    eq(caller(), owner),
                    // 是不是token的所有者
                    eq(caller(), tokenOwner)
                )) {
                    revert(0, 0)
                }
            }
            
            switch shr(224, calldataload(0x00)) // 逻辑右移224位，得到的结果的低4字节是函数选择器
                // 然后进行比较，它是低位比较的

                case 0xd8f361ad { // mint(bytes32,bytes32,address)
                    // 保证是owner才能操作
                    ensureOwner()
                    
                    // tokenId是这个token在storage的存放位置
                    let tokenId := calldataload(0x04)
                    let name := calldataload(0x24)
                    // 因为address不占32字节，因此这里用0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF取低20字节的内容
                    let owner := and(calldataload(0x44), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    
                    // 找到位置，然后存储这个token的name
                    sstore(tokenId, name)
                    // 然后存储这个token的owner
                    sstore(add(tokenId, 1), owner)
                }
                case 0xa9fde064 { // updateName(bytes32,bytes32)

                    let tokenId := calldataload(0x04)
                    let newName := calldataload(0x24)
                    
                    // 保证是owner或token的所有者，才能更新这个token的名字
                    ensureTokenOwner(tokenId)
                    sstore(tokenId, newName)
                }
                case 0x9711a543 { // updateOwner(bytes32,address)
                    let tokenId := calldataload(0x04)
                    let newOwner := and(calldataload(0x24), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    
                    // 保证是owner或token的所有者，才能更新这个token的所有者
                    ensureTokenOwner(tokenId)
                    sstore(add(tokenId, 1), newOwner)
                }
                case 0xbdce9bde { // updateApproval(bytes32,address)
                    let tokenId := calldataload(0x04)
                    let newApproval := and(calldataload(0x24), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    
                    // 保证是owner或token的所有者，才能更新这个token的授权情况
                    ensureTokenOwner(tokenId)
                    sstore(add(tokenId, 2), newApproval)
                }
                case 0x169dbe24 { // updateMetadata(bytes32,address)
                    let tokenId := calldataload(0x04)
                    let newMetadata := and(calldataload(0x24), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    
                    // 保证是owner或token的所有者，才能更新这个token的metadata
                    ensureTokenOwner(tokenId)
                    sstore(add(tokenId, 3), newMetadata)
                }
                case 0x54b8d5e3 { // getName(bytes32)
                    let tokenId := calldataload(0x04)
                    let tokenOwner := sload(tokenId)
                    
                    mstore(0x00, tokenOwner)
                    return(0x00, 0x20)
                }
                case 0xdeb931a2 { // getOwner(bytes32)
                    let tokenId := calldataload(0x04)
                    let tokenOwner := sload(add(tokenId, 1))
                    
                    mstore(0x00, tokenOwner)
                    return(0x00, 0x20)
                }
                case 0x1cb9a344 { // getApproval(bytes32)
                    let tokenId := calldataload(0x04)
                    let approved := sload(add(tokenId, 2))
                    
                    mstore(0x00, approved)
                    return(0x00, 0x20)
                }
                case 0xa5961b4c { // getMetadata(bytes32)
                    let tokenId := calldataload(0x04)
                    let tokenMetadata := sload(add(tokenId, 3))
                    
                    mstore(0x00, tokenMetadata)
                    return(0x00, 0x20)
                }
                case 0xf2fde38b { // transferOwnership(address)
                    // 只有owner才能转让owner，确定pendingOwner
                    ensureOwner()
                    
                    let newOwner := and(calldataload(0x04), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    sstore(0x01, newOwner)
                }
                case 0x79ba5097 { // acceptOwnership()
                    // 只有pendingOwner才能接收转让请求
                    ensurePendingOwner()
                    
                    sstore(0x00, sload(0x01))
                    // 成为新owner之后，将pendingOwner重新设置为空
                    sstore(0x01, 0x00)
                }
                // 其他任何操作都revert
                default {
                    revert(0, 0)
                }
        }
    }
}
