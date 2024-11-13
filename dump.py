#!/usr/bin/env python3

import time
import sys

sys.path.append("./python")
from Report             import Report
from ChainstateIterator import ChainstateIterator
from ChainstateParser   import ChainstateParser

chainstateDir = "/tmp/chainstate"
reportDir = "/tmp/"
reportFileName = "result.sqlite"

isDebugMode = False
isIterateByTransaction = False
iteratorTxId = "7f46911477faceffda100b149035d03852d9f3ab180c450723c97d36bd151d00"
iteratorTxIndex = None

isDumpBalance = True
isDumpTransactions = False
isDumpBadTransactions = False

limit = 0
count = 0
notDecoded = 0
decoded = 0

try:
    time0 = time.time()
    
    chainstate = ChainstateIterator(chainstateDir)

    modes = []
    if isDumpBalance        : modes.append("isDumpBalance")
    if isDumpTransactions   : modes.append("isDumpTransactions")
    if isDumpBadTransactions: modes.append("isDumpBadTransactions")

    report = Report(
        reportDir + reportFileName, modes
    )

    parser = ChainstateParser(
        chainstate.getObfuscateKey()
    )

    if isIterateByTransaction: iterator = chainstate.valuesByTransaction(iteratorTxId, iteratorTxIndex)
    else                     : iterator = chainstate.values()

    for key, value in iterator:
        if len(key) >= 34 and key[0] == 0x43:

            # Stop processing if overflow.
            if limit > 0 and count >= limit: break
            count += 1

            # Decode UTXO.
            txId, txIndex, height, coinbase, amount, outType, script, address = parser.parse(key, value)

            if count % 10_000 == 0:
                print(f"{count} records were processed.")

            if isDebugMode:
                if address != "": print(f"address : {address}")
                if address == "": print(f"address : n/a")
                print(f"txId    : {txId}")
                print(f"txIndex : {txIndex}")
                print(f"height  : {height}")
                print(f"coinbase: {coinbase}")
                print(f"amount  : {amount}")
                print(f"outType : {outType}")
                print(f"script  : {script}")
                print("")

            report.append(txId, amount, height, address)

            if address != "": decoded    += 1
            else            : notDecoded += 1

    countBalance, countTransactions, countBadTransactions = report.finalize()
    chainstate.finalize()

    time1 = time.time()

    print(f"Total iterations: {count}")
    print(f"Transactions decoded: {decoded}")
    print(f"Transactions not decoded: {notDecoded}")
    if isDumpBalance        : print(f"Records in final table 'balance': {countBalance}")
    if isDumpTransactions   : print(f"Records in final table 'transactions': {countTransactions}")
    if isDumpBadTransactions: print(f"Records in final table 'bad_transactions': {countBadTransactions}")
    print(f"Speed (in seconds): {time1 - time0}")

except Exception as error:
    print(f"{error}")
