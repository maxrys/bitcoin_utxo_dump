
import Foundation
import CryptoKit
import RIPEMD160

extension Data {

    init?(hexEncoded hex: String) {
        guard hex.count % 2 == 0 else {
            return nil
        }

        self.init(
            count: hex.count / 2
        )

        let charToValue = { (_ char:Character) -> UInt8? in
            switch char {
                case "0"..."9": return char.asciiValue! - 48      // "0" == 48
                case "A"..."F": return char.asciiValue! - 65 + 10 // "A" == 65
                case "a"..."f": return char.asciiValue! - 97 + 10 // "a" == 97
                default       : return nil
            }
        }

        for i in 0..<hex.count / 2 {
            let value1 = charToValue(hex[hex.index(hex.startIndex, offsetBy: i * 2 + 0)])
            let value2 = charToValue(hex[hex.index(hex.startIndex, offsetBy: i * 2 + 1)])
            guard value1 != nil else {return nil}
            guard value2 != nil else {return nil}
            self[i] = value1! * 16 + value2!
        }
    }

    func hexEncodedString() -> String {
        var result = ""
        for byte in self {
            if byte > 0xf {result +=       String(byte, radix: 16)}
            else          {result += "0" + String(byte, radix: 16)}
        }
        return result
    }

    private static let base58fastEncodeAlphabet = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "A", "B", "C", "D", "E", "F", "G", "H", "J",
        "K", "L", "M", "N", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z",
        "a", "b", "c", "d", "e", "f", "g", "h", "i",
        "j", "k", "m", "n", "o", "p", "q", "r", "s",
        "t", "u", "v", "w", "x", "y", "z"
    ]

    func base58() -> String {
        var zeroCount = 0
        var data = [UInt8]()
        for byte in self {
            if byte == 0 && data.isEmpty {
                zeroCount += 1
            } else {
                data.append(byte)
            }
        }

        let jMax = ((self.count * 138) / 100) + 1
        var jCurMax = 0
        var current: Int
        var j: Int
        var buffer = [UInt8](
            repeating: 0,
            count: jMax
        )

        for byte in data {
            current = Int(byte)
            j = 0
            repeat {
                current   = current + 256 * Int(buffer[j])
                buffer[j] = UInt8(current % 58)
                current   =       current / 58
                j += 1
            } while j < jMax && (current > 0 || j < jCurMax)
            jCurMax = j
        }

        while buffer.last == 0 {
            buffer.removeLast()
        }
        if zeroCount > 0 {
            buffer += [UInt8](
                repeating: 0,
                count: zeroCount
            )
        }

        var result:[Character] = []
        for byte in buffer {
            result.insert(
                contentsOf: Data.base58fastEncodeAlphabet[Int(byte)],
                at: 0
            )
        }
        return String(result)
    }

    func sha256() -> Data {
        let hash = SHA256.hash(data: self)
        return Data(hash)
    }

    func ripemd160() -> Data {
        return RIPEMD160.hash(
            data: self
        )
    }

}
