
import Foundation

let argc = CommandLine.arguments
let prog = "./" + URL(fileURLWithPath: argc[0]).lastPathComponent

if argc.count < 3 {
    print("syntax: \(prog) CHAINSTATE_DIR PATH_TO_NEW_SQLITE_REPORT")
    exit(1)
}

let chainstateDir = argc[1]
let reportDir = argc[2]
let reportFileName = "result.sqlite"

let isDebugMode = false
let isIterateByTansaction = false
let iteratorTxID = "7f46911477faceffda100b149035d03852d9f3ab180c450723c97d36bd151d00"
let iteratorTxIndex: Int? = nil

let isDumpBalance = true
let isDumpTransactions = false
let isDumpBadTransactions = false

let limit = 0
var count = 0
var notDecoded = 0
var decoded = 0

if Test.runForCore()   {print("TEST  'core'  OK")} else {print("!!! TEST  'core'  ERROR !!!"); exit(1)}
if Test.runForCrypto() {print("TEST 'crypto' OK")} else {print("!!! TEST 'crypto' ERROR !!!"); exit(1)}

do {
    let time0 = Date()

    let chainstate = try ChainstateIterator(
        path: chainstateDir
    )

    var modes: Set<Report.mode> = []
    if isDumpBalance         {modes.insert(.dumpBalance)}
    if isDumpTransactions    {modes.insert(.dumpTransactions)}
    if isDumpBadTransactions {modes.insert(.dumpBadTransactions)}

    let report = try Report(
        file: reportDir + reportFileName,
        modes: modes
    )

    let parser = ChainstateParser(
        obfuscateKey: chainstate.getObfuscateKey()
    )

    let iterator: KeyValueSequenceWrapper
    if isIterateByTansaction {iterator = chainstate.valuesByTransaction(txID: iteratorTxID, index: iteratorTxIndex)}
    else                     {iterator = chainstate.values()}

    for (key, value) in iterator {
        if key.count >= 34 && key[0] == 0x43 && value != nil {
            let key   = key
            let value = value!

            // Stop processing if overflow.
            if limit > 0 && count >= limit {break}
               count += 1

            // Decode UTXO.
            if let (txId, txIndex, height, coinbase, amount, outType, script, address) = parser.parse(tx: key, coin: value) {

                if count > 0 && count % 10_000 == 0 {
                    print("\(count) records were processed.")
                }

                if isDebugMode {
                    if address != "" {print("address : \(address )", terminator: "\n")}
                    if address == "" {print("address : n/a"        , terminator: "\n")}
                    print("txId    : \(txId    )"                  , terminator: "\n")
                    print("txIndex : \(txIndex )"                  , terminator: "\n")
                    print("height  : \(height  )"                  , terminator: "\n")
                    print("coinbase: \(coinbase)"                  , terminator: "\n")
                    print("amount  : \(amount  )"                  , terminator: "\n")
                    print("outType : \(outType )"                  , terminator: "\n")
                    print("script  : \(script.hexEncodedString())" , terminator: "\n")
                    print(""                                       , terminator: "\n")
                }

                try report.append(
                    txId: txId, amount: amount, height: height, address: address
                )

                if address != "" {decoded    += 1}
                else             {notDecoded += 1}

            } else {
                notDecoded += 1
            }
        }
    }

    let (countBalance, countTransactions, countBadTransactions) = try report.finalize()

    let time1 = Date()

    print("Total iterations: \(count)")
    print("Transactions decoded: \(decoded)")
    print("Transactions not decoded: \(notDecoded)")
    if isDumpBalance         {print("Records in final table 'balance': \(countBalance ?? 0)")}
    if isDumpTransactions    {print("Records in final table 'transactions': \(countTransactions ?? 0)")}
    if isDumpBadTransactions {print("Records in final table 'bad_transactions': \(countBadTransactions ?? 0)")}
    print("Speed (in seconds): \(time1.timeIntervalSince(time0))")

} catch {
    print("ERROR: \(error).")
}
