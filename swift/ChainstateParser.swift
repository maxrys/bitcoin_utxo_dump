
import Foundation
import BigInt

class ChainstateParser {

    private var obfuscateKey: Data?

    init(obfuscateKey: Data? = nil) {
        self.obfuscateKey = obfuscateKey
    }

    func parse(tx txData: Data, coin coinData: Data) -> (txId: String, txIndex: Int, height: Int, coinbase: Int, amount: Int, outType: Int, script: Data, address: String)? {
        var coinData = coinData

        // Deobfuscate value if "obfuscateKey" is exists.
        if self.obfuscateKey != nil {
            coinData = self.deobfuscate(
                value: coinData
            )
        }

        //
        //                                  "tx" structure
        //
        // ┌──────┬──────────────────────────────────────────────────────────────────┬──────┐
        // │ type │                       TXID (little-endian)                       │ vout │
        // ├──────┼──────────────────────────────────────────────────────────────────┼──────┤
        // │  43  │ 000003502797e99d1cc6f9497253b2290514fdf647e12487c20c4b20e3833e03 │  00  │
        // └──────┴──────────────────────────────────────────────────────────────────┴──────┘
        //      type: 1 byte of key code (67 = 0x43 = C = "utxo")
        //      txid: 32 bytes TXID (Little endian)
        //      vout: 1 byte (Base128 VarInt)
        //
        // Original source code:
        // https://github.com/bitcoin/bitcoin/blob/ea729d55b4dbd17a53ced474a8457d4759cfb5a5/src/txdb.cpp#L40-L53
        //

        var txID = txData[1...32]
        txID.reverse()

        let txIndex = ChainstateParser.decodeVarInt(
            Data(
                txData[33...]
            )
        )

        //                            "coin" structure
        //
        // ┌────────┬────────┬────────┬──────────────────────────────────────────┐
        // │        │ amount │        │                                          │
        // │ VarInt │ VarInt │ nSize  │                  script                  │
        // │        │ compr  │        │                                          │
        // ├────────┼────────┼────────┼──────────────────────────────────────────┤
        // │ 71a9e8 │ 7d62de │   25   │ 953e189f706bcf59263f15de1bf6c893bda9b045 │
        // │ ------------------------------- xor ------------------------------- │
        // │ b12dce │ fd8f87 │   25   │ 36b12dcefd8f872536b12dcefd8f872536b12dce │
        // │ -------------------------------- = -------------------------------- │
        // │ c08426 │ 80ed59 │   00   │ a38f35518de4487c108e3810e6794fb68b189d8b │
        // └────│───┴────────┴────────┴──────────────────────────────────────────┘
        //      │
        //    decode
        //      │
        //      ▼
        // ┌──────────────────────┬──────────┐
        // │        height        │ coinbase │
        // ├──────────────────────┼──────────┤
        // │ 10000010000101010011 │    0     │
        // └──────────────────────┴──────────┘
        //
        //     column 1: Height (first 19 bits, decoded VarInt), Coinbase (last bit)
        //     column 2: amount (decoded, compressed, in Satoshis)
        //     nSize   : the type of scriptpubkey (P2PKH, P2SH, P2PK), or the size of the upcoming script
        //     script  : P2PKH/P2SH hash160, P2PK public key, or complete script
        //
        // Original source code:
        // https://github.com/bitcoin/bitcoin/blob/6c4fecfaf7beefad0d1c3f8520bf50bb515a0716/src/coins.h#L58-L64
        //

        var offset = 0
        var data: Data

        (data, offset) = ChainstateParser.parseBase128(data: coinData, offset: offset)
        let coinbaseAndHeightData = ChainstateParser.decodeVarInt(data)
        let height   = coinbaseAndHeightData >> 1
        let coinbase = coinbaseAndHeightData & 0b0000_0001

        (data, offset) = ChainstateParser.parseBase128(data: coinData, offset: offset)
        let amountData = ChainstateParser.decodeVarInt(data)
        let amount = ChainstateParser.decompressAmount(amountData)

        (data, offset) = ChainstateParser.parseBase128(data: coinData, offset: offset)
        let outType = ChainstateParser.decodeVarInt(data)

        // 0  = P2PKH: script is the Hash160 public key  (address start with "1...")
        // 1  = P2SH : script is the Hash160 of a script (address start with "3...")
        // 2  = P2PK : script is a compressed public key (dataSize makes up part of the public key, y=even)
        // 3  = P2PK : script is a compressed public key (dataSize makes up part of the public key, y=odd)
        // 4  = P2PK : script is an uncompressed public key (but has been compressed for LevelDB, y=even)
        // 5  = P2PK : script is an uncompressed public key (but has been compressed for LevelDB, y=odd)
        // 6+ =      : indicates size of full script (subtract 6 to get the size in bytes)

        let dataSize: Int
        switch outType {
            case 0 : dataSize = 20
            case 1 : dataSize = 20
            case 2 : dataSize = 33; offset -= 1 // 1 byte for the type + 32 bytes of data
            case 3 : dataSize = 33; offset -= 1 // 1 byte for the type + 32 bytes of data
            case 4 : dataSize = 33; offset -= 1 // 1 byte for the type + 32 bytes of data
            case 5 : dataSize = 33; offset -= 1 // 1 byte for the type + 32 bytes of data
            default: dataSize = outType - 6
        }

        let script = coinData[offset...]

        guard script.count == dataSize else {
            return nil
        }

        var address = ""
        switch outType {
            case 0 : address = ChainstateParser.addressP2PKH(Data([0]) + script)
            case 1 : address = ChainstateParser.addressP2PKH(Data([5]) + script)
            case 2 : address = ChainstateParser.addressP2PK(script)
            case 3 : address = ChainstateParser.addressP2PK(script)
            case 4 : address = ChainstateParser.addressP2PK(ChainstateParser.decompressPublicKey(key: script))
            case 5 : address = ChainstateParser.addressP2PK(ChainstateParser.decompressPublicKey(key: script))
            default: address = ""
        }

        return (
            txId    : txID.hexEncodedString(),
            txIndex : txIndex,
            height  : height,
            coinbase: coinbase,
            amount  : amount,
            outType : outType,
            script  : script,
            address : address
        )
    }

    func deobfuscate(value: Data) -> Data {
        var result = Data()
        let obfuscateKey = self.obfuscateKey!
        var i = 0
        for _ in value {
            result.append(
                value[i] ^ // Bitwise XOR Operator
                obfuscateKey[i < obfuscateKey.count ? i :
                             i % obfuscateKey.count]
            )
            i += 1
        }
        return result
    }

    static func encodeVarInt(_ value: Int) -> Data {
        //
        // Original source code:
        // https://github.com/bitcoin/bitcoin/blob/v0.13.2/src/serialize.h#L344
        //
        if value == 0 {
            return Data([0])
        }
        var value = value
        var result = Data(repeating: 0, count: 10)
        var i = 0
        while true {
            result[i] = UInt8((value & 0b0111_1111) | (i != 0 ? 0b1000_0000 : 0x0000_0000))
            if value <= 0b0111_1111 {break}
            value = (value >> 7) - 1
            i += 1
        }
        while result.last == 0 {
            result.removeLast()
        }
        result.reverse()
        return result
    }

    static func decodeVarInt(_ data: Data) -> Int {
        //
        // Original source code:
        // https://github.com/bitcoin/bitcoin/blob/v0.13.2/src/serialize.h#L360#L372
        //
        // ┌────────┬──────────┬───────────────────────────────────────────┐
        // │ b98276 │  a2ec77  │ 0cbc2986ff9aed6825920aece14aa6f5382ca5580 │
        // └────────┴────│─────┴───────────────────────────────────────────┘
        //               │
        // ┌─────────────▼──────────────┐
        // │ 10100010 11101100 01110111 │
        // ├──── ↓ ────── ↓ ────── ↓ ───┤
        // │  0100010  1101100  1110111 │
        // ├──── + ────── + ────────────┤
        // │  0000001  0000001          │
        // ├──── = ────── = ────── = ───┤
        // │  0100011  1101101  1110111 │
        // └─────│──│─────│──│─────│────┘
        //       │  └─┐   │  └─┐   │
        // ┌─────▼────▼───▼────▼───▼────┐
        // │ 00001000_11110110_11110111 │
        // └────────────────────────────┘
        //               │
        // ┌─────────────▼──────────────┐
        // │           587511           │
        // └────────────────────────────┘
        //

        var n = 0
        for chData in data {
            n = (n << 7) | (Int(chData) & 0b0111_1111)
            if chData & 0b1000_0000 != 0 {
                n += 1
            } else {
                return n
            }
        }
        return 0
    }

    static func parseBase128(data: Data, offset: Int = 0) -> (Data, Int) {
        //
        // ┌────────┬──────────┬───────────────────────────────────────────┐
        // │ b98276 │  a2ec77  │ 0cbc2986ff9aed6825920aece14aa6f5382ca5580 │
        // └────────┴────│─────┴───────────────────────────────────────────┘
        //               ▼     ┌─ stop-bit
        // ┌───────────────────▼────────┐
        // │ 10100010 11101100 01110111 │
        // └────────────────────────────┘
        //
        var offset = offset
        var result = Data()
        var hasMoreBytes: UInt8

        repeat {
            result.append(data[offset])
            hasMoreBytes = data[offset] & 0b1000_0000
            offset += 1
        } while hasMoreBytes != 0

        return (result, offset)
    }

    static func decompressAmount(_ value: Int) -> Int {
        //
        // Original source code:
        // https://github.com/bitcoin/bitcoin/blob/v0.13.2/src/compressor.cpp#L161#L185
        //
        var x = value

        // reuslt 1: x = 0
        // reuslt 2: x = 1 + 10 * (9 * n + d - 1) + e
        // reuslt 3: x = 1 + 10 * (    n     - 1) + 9

        if x == 0 {
            return 0
        }

        // x = 10 * (9 * n + d - 1) + e
        x -= 1
        var e = x % 10
        var n = 0
        x /= 10

        if e < 9 {
            // x = 9 * n + d - 1
            let d = (x % 9) + 1
            x /= 9;
            // x = n
            n = x * 10 + d
        } else {
            n = x + 1
        }

        while e > 0 {
            n *= 10
            e -= 1
        }

        return n
    }

    static func decompressPublicKey(key: Data) -> Data {
        var buffer = key

        // First byte (indicates whether y is Even or Odd).
        let prefix = buffer.removeFirst()

        // y^2 = x^3 + 7 mod p
        let p = BigUInt("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", radix: 16)!
        let x = BigUInt(buffer)
        let xPow3ModP = x.power(3, modulus: p) // x^3 mod p
        let ySqrt2 = (xPow3ModP + 7) % p
        var y = ySqrt2.power((p + 1) / 4, modulus: p) // Square root of Y in secp256k1 = y^((p+1)/4).
        let yMod2 = y % 2 // Determine if the Y we have caluclated is Even or Odd.

        if prefix % 2 == 0 && yMod2 != 0 {y = (p - y) % p} // If prefix is Even (indicating an Even Y Value) and Y is Odd, use other Y value.
        if prefix % 2 != 0 && yMod2 == 0 {y = (p - y) % p} // If prefix is Odd (indicating an Odd Y Value) and Y is Even, use other Y Value.

        var yData = y.serialize()

        // Make sure y value is 32 bytes in length.
        while yData.count < 32 {
            yData.insert(0, at: 0)
        }

        // Return full X and Y coordinates (with 0x04 prefix) as a byte array.
        return Data([0x04] + buffer + yData)
    }

    static func addressP2PKH(_ vh160: Data) -> String {
        let checksum = Data(vh160.sha256().sha256()[0...3])
        return Data(vh160 + checksum).base58()
    }

    static func addressP2PK(_ pubKey: Data) -> String {
        let result = Data([0] + pubKey.sha256().ripemd160())
        let resultChecksum = Data(result.sha256().sha256()[0...3])
        return (result + resultChecksum).base58()
    }

}
