from random import SystemRandom
from ecdsa import ecdsa
import sha3
import binascii
from typing import Tuple
import uuid
import os

# 定义生成密钥对的函数 : 这个函数生成一个 ECDSA 密钥对，其中包括私钥 priv 和对应的公钥 pub
def gen_keypair() -> Tuple[ecdsa.Private_key, ecdsa.Public_key]:
    """
    generate a new ecdsa keypair
    """
    # 选择椭圆曲线参数 secp256k1
    g = ecdsa.generator_secp256k1
    # 随机生成私钥 d，范围在 [1, g.order()) 内
    d = SystemRandom().randrange(1, g.order())
    # 计算公钥 pub = g * d
    pub = ecdsa.Public_key(g, g * d)
    priv = ecdsa.Private_key(pub, d)
    return priv, pub

# 定义生成会话密钥的函数: 这个函数生成一个随机的 32 字节会话密钥
def gen_session_secret() -> int:
    """
    generate a random 32 byte session secret
    """
    # 使用 /dev/urandom 生成随机数据
    with open("/dev/urandom", "rb") as rnd:
        seed1 = int(binascii.hexlify(rnd.read(32)), 16)
        seed2 = int(binascii.hexlify(rnd.read(32)), 16)
    return seed1 ^ seed2

# 定义哈希消息的函数: 这个函数将输入的字符串消息哈希为一个整数，用于签名
def hash_message(msg: str) -> int:
    """
    hash the message using keccak256, truncate if necessary
    """
    k = sha3.keccak_256()
    k.update(msg.encode("utf8"))
    d = k.digest()
    n = int(binascii.hexlify(d), 16)
    olen = ecdsa.generator_secp256k1.order().bit_length() or 1
    dlen = len(d)
    n >>= max(0, dlen - olen)
    return n


if __name__ == "__main__":
    # 获取标志信息或设置默认标志
    # 这里获取环境变量中的 FLAG 值作为标志信息，如果环境变量中没有设置，则使用默认的占位标志
    flag = os.getenv("FLAG", "PCTF{placeholder}")

    # 生成 ECDSA 密钥对和会话密钥
    # 通过调用之前定义的 gen_keypair() 函数生成 ECDSA 密钥对，然后调用 gen_session_secret() 函数生成会话密钥。
    priv, pub = gen_keypair()
    session_secret = gen_session_secret()

    # 在这个循环中，程序四次要求用户输入消息，然后对消息进行哈希处理。
    # 接着，使用 priv.sign() 方法对哈希值进行签名，其中 priv 是之前生成的私钥，
    # session_secret 是会话密钥。签名后，程序打印出签名的 r 和 s 值。
    for _ in range(4):
        message = input("message? ")
        hashed = hash_message(message)
        sig = priv.sign(hashed, session_secret)
        print(f"r=0x{sig.r:032x}")
        print(f"s=0x{sig.s:032x}")

    # 生成测试哈希值并验证签名
    # 首先，程序生成一个随机的测试哈希值并打印出来。然后，程序等待用户输入 r 和 s 值。
    test = hash_message(uuid.uuid4().hex)
    print(f"test=0x{test:032x}")

    r = int(input("r? "), 16)
    s = int(input("s? "), 16)

    # 程序使用公钥 pub 对测试哈希值进行验证，检查用户输入的签名是否有效。
    # 如果验证失败，程序输出一条失败消息并退出
    # 这就意味着，我们需要获得产生这个公钥的私钥，然后拿这个私钥签名一个信息（就是这里的test）
    # 获得这个信息的r和s
    if not pub.verifies(test, ecdsa.Signature(r, s)):
        print("better luck next time")
        exit(1)

    print(flag)
