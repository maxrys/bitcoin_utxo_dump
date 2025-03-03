
import Foundation

struct KeyValueSequenceWrapper: Sequence, IteratorProtocol {

    private enum WorkMode {
        case pureData
        case iterator
    }

    private let workMode: WorkMode
    private let dataRows: [(Data, Data?)]?
    private var dataRowI: Int = 0
    private let sequence: KeyValueSequence?
    private let iterator: AnyIterator<(Data, Data?)>?

    init(dataRows: [(Data, Data?)]) {
        self.workMode = .pureData
        self.sequence = nil
        self.iterator = nil
        self.dataRows = dataRows
    }

    init(sequence: KeyValueSequence) {
        self.workMode = .iterator
        self.sequence = sequence
        self.iterator = sequence.makeIterator()
        self.dataRows = []
    }

    mutating func next() -> (Data, Data?)? {
        if self.workMode == .pureData {
            if self.dataRowI < self.dataRows!.count {
                let result = self.dataRows![self.dataRowI]
                self.dataRowI += 1
                return result
            }
        }
        if self.workMode == .iterator {
            if let (key, value) = self.iterator?.next() {
                return (key, value)
            }
        }
        return nil
    }

}

class ChainstateIterator {

    private let path: String
    private let connection: Database
    private var obfuscateKey: Data?

    init(path: String) throws {
        self.path = path
        // Set connection.
        self.connection = try Database.create(
            path: self.path,
            comparator: DefaultComparator()
        )
        // Set "obfuscate_key".
        if let obfuscateKey = try self.connection.get(Data("\u{e}\0obfuscate_key".utf8)) {
            self.obfuscateKey = Data(obfuscateKey[1...])
        }
    }

    func getObfuscateKey() -> Data? {
        return obfuscateKey
    }

    func values() -> KeyValueSequenceWrapper {
        return KeyValueSequenceWrapper(
            sequence: self.connection.values()
        )
    }

    func valuesByTransaction(txID: String, index: Int? = nil) -> KeyValueSequenceWrapper {
        if let txIdData = Data(hexEncoded: txID) {
            if index != nil {
                var key = Data([0x43]) + txIdData.reversed()
                    key = key + ChainstateParser.encodeVarInt(index!)
                if let value = try? self.connection.get(key) {
                    return KeyValueSequenceWrapper(
                        dataRows: [(key, value)]
                    )
                }
            } else {
                var i = 0
                var attempts = 0
                var result: [(Data, Data?)] = []
                while true {
                    if attempts >= 3 {
                        break
                    }
                    var key = Data([0x43]) + txIdData.reversed()
                        key = key + ChainstateParser.encodeVarInt(i)
                    if let value = try? self.connection.get(key) {
                        result.append(
                            (key, value)
                        )
                    } else {
                        attempts += 1
                    }
                    i += 1
                }
                return KeyValueSequenceWrapper(
                    dataRows: result
                )
            }
        }
        return KeyValueSequenceWrapper(
            dataRows: []
        )
    }

}
