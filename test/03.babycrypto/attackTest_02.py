from ecdsa import ecdsa, SigningKey
from ecdsa.numbertheory import inverse_mod
from hashlib import sha1

# g: chal.py使用的特定加密曲线算法。
# r: 相同的r值
# sA,sB: 输入message, 然后chal.py输出的s
# hashA,hashB: 输入的message的hash值

g = ecdsa.generator_secp256k1
publicKeyOrderInteger = g.order()

r = "e430b3a398f2320556eef81c1c523ea5ae0a920f493c8376eafcb0dc9cd75b89" # 相同的r值

sA = "bbfb7b34c31f025bddb8724a53dae7dd5a17c489587b881b8ed0dc5453c07e87" # 消息`</3`的s
sB = "43d8ec82d7b6b1f3c8ed41b0ba682d5291f6d4a922a57729fa716dccd0f237d6" # 消息`no`的s

hashA = "45951261090588542051596130132754692813999860320220484796045003839994507210350" # `</3`的hash值
hashB = "56710668495515998944273818574660611208941006033402527734960197520384934694586" # `no`的哈希值

r1 = int(r, 16)
s1 = int(sA, 16)
s2 = int(sB, 16)

L1 = int(hashA, 10)
L2 = int(hashB, 10)

numerator = (((s2 * L1) % publicKeyOrderInteger) - ((s1 * L2) % publicKeyOrderInteger))
denominator = inverse_mod(r1 * ((s1 - s2) % publicKeyOrderInteger), publicKeyOrderInteger)

privateKey = numerator * denominator % publicKeyOrderInteger

print(privateKey)