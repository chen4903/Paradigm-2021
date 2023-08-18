pragma solidity 0.4.24;

// 接口
contract ERC20Like {
    function transfer(address dst, uint qty) public returns (bool);
    function transferFrom(address src, address dst, uint qty) public returns (bool);
    function approve(address dst, uint qty) public returns (bool);
    
    function balanceOf(address who) public view returns (uint);
}

contract Bank {
    address public owner;
    address public pendingOwner;
    
    struct Account {
        string accountName;
        uint uniqueTokens;
        mapping(address => uint) balances;
    }
    
    mapping(address => Account[]) accounts;
    
    constructor() public {
        owner = msg.sender;
    }
    
    // 存款 
    function depositToken(uint accountId, address token, uint amount) external {
        require(accountId <= accounts[msg.sender].length, "depositToken/bad-account");
        
        // 可以新建一个token存款
        if (accountId == accounts[msg.sender].length) {
            accounts[msg.sender].length++;
        }
        
        Account storage account = accounts[msg.sender][accountId];
        uint oldBalance = account.balances[token];
        
        // 检查用户是否有足够的余额，并且不会发生溢出
        require(oldBalance + amount >= oldBalance, "depositToken/overflow");
        require(ERC20Like(token).balanceOf(msg.sender) >= amount, "depositToken/low-sender-balance");
        
        // increment counter for unique tokens if necessary
        if (oldBalance == 0) {
            account.uniqueTokens++;
        }
        
        // update the balance
        account.balances[token] += amount;
        
        // transfer the tokens in
        uint beforeBalance = ERC20Like(token).balanceOf(address(this));
        // 似乎这个transferFrom()可以重入，可控的外部方法
        require(ERC20Like(token).transferFrom(msg.sender, address(this), amount), "depositToken/transfer-failed");
        uint afterBalance = ERC20Like(token).balanceOf(address(this));
        require(afterBalance - beforeBalance == amount, "depositToken/fee-token");
    }
    
    // 取款
    function withdrawToken(uint accountId, address token, uint amount) external {
        require(accountId < accounts[msg.sender].length, "withdrawToken/bad-account");
        
        Account storage account = accounts[msg.sender][accountId];
        uint lastAccount = accounts[msg.sender].length - 1;
        uint oldBalance = account.balances[token];
        
        // check the user can actually withdraw the amount they want and we have enough balance
        require(oldBalance >= amount, "withdrawToken/underflow");
        require(ERC20Like(token).balanceOf(address(this)) >= amount, "withdrawToken/low-sender-balance");
        
        // update the balance
        account.balances[token] -= amount;
        
        // if the user has emptied their balance, decrement the number of unique tokens
        if (account.balances[token] == 0) {
            account.uniqueTokens--;
            
            // if the user is withdrawing everything from their last account, close it
            // we can't close accounts in the middle of the array because we can't
            // clone the balances mapping, so the user would lose all their balance
            if (account.uniqueTokens == 0 && accountId == lastAccount) {
                accounts[msg.sender].length--;
            }
        }
        
        // transfer the tokens out
        uint beforeBalance = ERC20Like(token).balanceOf(msg.sender);
        require(ERC20Like(token).transfer(msg.sender, amount), "withdrawToken/transfer-failed");
        uint afterBalance = ERC20Like(token).balanceOf(msg.sender);
        require(afterBalance - beforeBalance == amount, "withdrawToken/fee-token");
    }
    
    // 设置account的名字
    function setAccountName(uint accountId, string name) external {
        require(accountId < accounts[msg.sender].length, "setAccountName/invalid-account");
        
        accounts[msg.sender][accountId].accountName = name;
    }
    
    // 关闭一个account：只有此account才可关闭
    function closeLastAccount() external {
        // make sure the user has an account
        require(accounts[msg.sender].length > 0, "closeLastAccount/no-accounts");
        
        // make sure the last account is empty
        uint lastAccount = accounts[msg.sender].length - 1;
        require(accounts[msg.sender][lastAccount].uniqueTokens == 0, "closeLastAccount/non-empty");
        
        // close the account
        accounts[msg.sender].length--;
    }
    
    // 获取account信息
    function getAccountInfo(uint accountId) public view returns (string, uint) {
        require(accountId < accounts[msg.sender].length, "getAccountInfo/invalid-account");
        
        return (
            accounts[msg.sender][accountId].accountName,
            accounts[msg.sender][accountId].uniqueTokens
        );
    }
    
    // 获取某个account的总共有多少个token
    function getAccountBalance(uint accountId, address token) public view returns (uint) {
        require(accountId < accounts[msg.sender].length, "getAccountBalance/invalid-account");
        
        return accounts[msg.sender][accountId].balances[token];
    }
    
    // owner转让
    function transferOwnership(address newOwner) public {
        require(msg.sender == owner);
        
        pendingOwner = newOwner;
    }
    
    // 接收owner转让
    function acceptOwnership() public {
        require(msg.sender == pendingOwner);
        
        owner = pendingOwner;
        pendingOwner = address(0x00);
    }
}