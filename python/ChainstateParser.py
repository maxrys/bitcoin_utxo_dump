import hashlib
from binascii import hexlify
from base58 import b58encode # pip3 install base58

def sha256(data):
    return hashlib.sha256(data).digest()

def ripemd160(data):
    return hashlib.new('ripemd160', data).digest()

def bigIntToArray(value):
    result = []
    while True:
        result.insert(0, value & 0b1111_1111)
        value = value >> 8
        if value == 0:
            break
    return result

class ChainstateParser:

    def __init__(self, obfuscateKey = None):
        self.obfuscateKey = obfuscateKey

    def parse(self, tx, coin):
        # Deobfuscate value if "obfuscateKey" is exists.
        if self.obfuscateKey is not None:
            coin = self.deobfuscate(coin)

        # Get Transaction ID.
        txId = tx[1:33]
        txId = bytes(reversed(txId))

        # Get Transaction Index.
        txIndex = self.decodeVarInt(
            tx[33:]
        )

        # Get Height and Coinbase.
        data, offset = self.parseBase128(coin)
        data = self.decodeVarInt(data)
        height   = data >> 1
        coinbase = data & 0b0000_0001

        # Get Amount.
        data, offset = self.parseBase128(coin, offset)
        data = self.decodeVarInt(data)
        amount = self.decompressAmount(data)

        # Get Out Type.
        data, offset = self.parseBase128(coin, offset)
        outType = self.decodeVarInt(data)

        # 0  = P2PKH: script is the Hash160 public key  (address start with "1...")
        # 1  = P2SH : script is the Hash160 of a script (address start with "3...")
        # 2  = P2PK : script is a compressed public key (dataSize makes up part of the public key, y=even)
        # 3  = P2PK : script is a compressed public key (dataSize makes up part of the public key, y=odd)
        # 4  = P2PK : script is an uncompressed public key (but has been compressed for LevelDB, y=even)
        # 5  = P2PK : script is an uncompressed public key (but has been compressed for LevelDB, y=odd)
        # 6+ =      : indicates size of full script (subtract 6 to get the size in bytes)

        # Calculate dataSize.
        match outType:
            case 0: dataSize = 20
            case 1: dataSize = 20
            case 2: dataSize = 33; offset -= 1 # 1 byte for the type + 32 bytes of data
            case 3: dataSize = 33; offset -= 1 # 1 byte for the type + 32 bytes of data
            case 4: dataSize = 33; offset -= 1 # 1 byte for the type + 32 bytes of data
            case 5: dataSize = 33; offset -= 1 # 1 byte for the type + 32 bytes of data
            case _: dataSize = outType - 6

        # Get Script.
        script = coin[offset:]

        # Assert that the script hash the expected length.
        assert len(script) == dataSize

        match outType:
            case 0: address = self.addressP2PKH(b"\x00" + script).decode("utf8")
            case 1: address = self.addressP2PKH(b"\x05" + script).decode("utf8")
            case 2: address = self.addressP2PK(script).decode("utf8")
            case 3: address = self.addressP2PK(script).decode("utf8")
            case 4: address = self.addressP2PK(ChainstateParser.decompressPublicKey(script)).decode("utf8")
            case 5: address = self.addressP2PK(ChainstateParser.decompressPublicKey(script)).decode("utf8")
            case _: address = ""

        txId   = hexlify( txId ).decode("utf8")
        script = hexlify(script).decode("utf8")

        return txId, txIndex, height, coinbase, amount, outType, script, address

    def deobfuscate(self, value):
        result = bytearray(b"")
        i = 0
        for _ in value:
            result.append(
                value[i] ^ # Bitwise XOR Operator.
                self.obfuscateKey[i if i < len(self.obfuscateKey)
                                  else i % len(self.obfuscateKey)]
            )
            i += 1
        return result

    @staticmethod
    def encodeVarInt(value):
        # Original source code:
        # https://github.com/bitcoin/bitcoin/blob/v0.13.2/src/serialize.h#L344
        if value == 0:
            return bytes([0])
        result = [0] * 10
        i = 0
        while True:
            result[i] = (value & 0b0111_1111) | (0b1000_0000 if i else 0x0000_0000)
            if value <= 0b0111_1111:
                break
            value = (value >> 7) - 1
            i += 1
        while len(result) and result[-1] == 0:
            result.pop()
        return bytes(reversed(result))

    @staticmethod
    def decodeVarInt(data):
        # Original source code:
        # https://github.com/bitcoin/bitcoin/blob/v0.13.2/src/serialize.h#L360#L372
        value = 0
        i = 0
        while True:
            value = (value << 7) | (data[i] & 0b0111_1111)
            if data[i] & 0b1000_0000:
                value += 1
                i += 1
            else:
                return value

    @staticmethod
    def parseBase128(utxo, offset = 0):
        result = bytearray(b"")
        while True:
            result.append(utxo[offset])
            hasMoreBytes = utxo[offset] & 0b1000_0000
            offset += 1
            if hasMoreBytes == 0:
                break
        return result, offset

    @staticmethod
    def decompressAmount(x):
        # Original source code:
        # https://github.com/bitcoin/bitcoin/blob/v0.13.2/src/compressor.cpp#L161#L185

        # x = 0
        if x == 0: return 0

        # x = 10 * (9 * n + d - 1) + e
        x -= 1
        e = x % 10
        n = 0
        x = x // 10

        if e < 9:
            # x = 9 * n + d - 1
            d = (x % 9) + 1
            x = x // 9
            # x = n
            n = x * 10 + d
        else:
            n = x + 1

        while e:
            n *= 10
            e -= 1

        return int(n)

    @staticmethod
    def decompressPublicKey(key):
        buffer = bytearray(key)
        
        # First byte (indicates whether y is Even or Odd).
        prefix = buffer.pop(0)

        # y^2 = x^3 + 7 mod p
        p = 115792089237316195423570985008687907853269984665640564039457584007908834671663 # == "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
        x = int.from_bytes(buffer)
        xPow3ModP = pow(x, 3, p) # x^3 mod p
        ySqrt2 = (xPow3ModP + 7) % p
        y = pow(ySqrt2, int((p + 1) // 4), p) # Square root of Y in secp256k1 = y^((p+1)/4).
        yMod2 = y % 2 # Determine if the Y we have caluclated is Even or Odd.

        if prefix % 2 == 0 and yMod2 != 0: y = (p - y) % p # If prefix is Even (indicating an Even Y Value) and Y is Odd, use other Y value.
        if prefix % 2 != 0 and yMod2 == 0: y = (p - y) % p # If prefix is Odd (indicating an Odd Y Value) and Y is Even, use other Y Value.

        yData = bigIntToArray(y)

        # Make sure y value is 32 bytes in length.
        while len(yData) < 32:
            yData.insert(0, 0)

        # Return full X and Y coordinates (with 0x04 prefix) as a byte array.
        return bytearray([0x04]) + buffer + bytearray(yData)

    @staticmethod
    def addressP2PKH(pubKey):
        checksum = sha256(sha256(pubKey))
        return b58encode(pubKey + checksum[0:4])

    @staticmethod
    def addressP2PK(pubKey):        
        result = b"\x00" + ripemd160(sha256(pubKey))
        resultChecksum = sha256(sha256(result))[0:4]
        return b58encode(result + resultChecksum)
