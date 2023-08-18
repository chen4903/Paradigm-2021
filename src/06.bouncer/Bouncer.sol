pragma solidity 0.8.0;

interface ERC20Like {
    function transfer(address dst, uint qty) external returns (bool);
    function transferFrom(address src, address dst, uint qty) external returns (bool);
    function approve(address dst, uint qty) external returns (bool);
    function allowance(address src, address dst) external returns (uint256);
    function balanceOf(address who) external view returns (uint);
}

contract Bouncer {
    // 学AAVE的ETH地址
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant entryFee = 1 ether;

    address owner;
    constructor() payable {
        owner = msg.sender;
    }

    mapping (address => address) public delegates;
    mapping (address => mapping (address => uint256)) public tokens;
    struct Entry {
        uint256 amount;
        uint256 timestamp;
        ERC20Like token;
    }
    mapping (address => Entry[]) entries;

    // 添加Entry
    function enter(address token, uint256 amount) public payable {
        // 每次调用都要 1ether
        require(msg.value == entryFee, "err fee not paid");
        entries[msg.sender].push(Entry ({
            amount: amount,
            token: ERC20Like(token),
            timestamp: block.timestamp
        }));
    }

    // 批量存款
    function convertMany(address who, uint256[] memory ids) payable public {
        for (uint256 i = 0; i < ids.length; i++) {
            convert(who, ids[i]);
        }
    }

    // 查询：某用户的存款情况
    function contributions(address who, address[] memory coins) public view returns (uint256[] memory) {
        uint256[] memory res = new uint256[](coins.length);
        for (uint256 i = 0; i < coins.length; i++) {
            res[i] = tokens[who][coins[i]];
        }
        return res;
    }

    // 存款：可用ETH或者token，简易版的AAVE
    function convert(address who, uint256 id) payable public {
        Entry memory entry = entries[who][id];
        // 也就是说不能在一笔交易里面添加Entry然后convert,要等一会
        require(block.timestamp != entry.timestamp, "err/wait after entering");
        // 如果不是ETH，则需要who在授权全额的token给本合约
        if (address(entry.token) != ETH) {
            require(entry.token.allowance(who, address(this)) == type(uint256).max, "err/must give full approval");
        }
        // 只有自己或者经过授权的人才能操作此方法
        require(msg.sender == who || msg.sender == delegates[who]);
        // 简易版的AAVE：转账机制
        proofOfOwnership(entry.token, who, entry.amount);
        tokens[who][address(entry.token)] += entry.amount;
    }
    function proofOfOwnership(ERC20Like token, address from, uint256 amount) public payable {
        if (address(token) == ETH) {
            require(msg.value == amount, "err/not enough tokens");
        } else {
            require(token.transferFrom(from, address(this), amount), "err/not enough tokens");
        }
    }

    // 取款
    function redeem(ERC20Like token, uint256 amount) public {
        tokens[msg.sender][address(token)] -= amount;
        payout(token, msg.sender, amount);
    }
    function payout(ERC20Like token, address to, uint256 amount) private {
        if (address(token) == ETH) {
            payable(to).transfer(amount);
        } else {
            require(token.transfer(to, amount), "err/not enough tokens");
        }
    }

    // 授权：只有经过批准的人才可以帮我存款
    function addDelegate(address from, address to) public {
        require(msg.sender == owner || msg.sender == from);
        delegates[from] = to;
    }

    // 取消授权
    function removeDelegate(address from) public {
        require(msg.sender == owner || msg.sender == from);
        delete delegates[from];
    }

    // owner可拿走此合约的所有ETH，虽然写的是fee
    function claimFees() public {
        require(msg.sender == owner);
        payable(msg.sender).transfer(address(this).balance);
    }

    // owner可以用这个方法调用任何方法，也就是任何逻辑
    function hatch(address target, bytes memory data) public {
        require(msg.sender == owner);
        (bool ok, bytes memory res) = target.delegatecall(data);
        require(ok, string(res));
    }
}

contract Party {
    Bouncer bouncer;
    constructor(Bouncer _bouncer) {
        bouncer = _bouncer;
    }

    function isAllowed(address who) public view returns (bool) {
        address[] memory res = new address[](2);
        res[0] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        res[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        // 查询用户who存的所有代币余额
        uint256[] memory contribs = bouncer.contributions(who, res);
        // 计算总余额
        uint256 sum;
        for (uint256 i = 0; i < contribs.length; i++) {
            sum += contribs[i];
        }
        // 如果用户总余额大于1000则返回true
        return sum > 1000 * 1 ether;
    }
}
