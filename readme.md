


# Bitcoin Chainstate parser.

Two versions with identical functionality were developed in **Python** and **Swift**.

Processes only *transactions* for the following types:

- `P2PKH` (address start with "1...");
- `P2SH` (address start with "3...");
- `P2PK` (coinbase).

See the project [https://github.com/in3rsha/bitcoin-utxo-dump.git](url) if you need to parse transactions with `P2MS`, `P2WPKH`, `P2WSH`, `P2TR`.

See the page [https://github.com/in3rsha/bitcoin-chainstate-parser](url) if you want to read a nice description of the parsing algorithm.

The parsing result is uploaded to the SQLite database.

**Copy full *chainstate* to `/tmp/chainstate/`**



# PYTHON version

The following libraries must be installed:

    pip3 install amulet-leveldb
    pip3 install base58

## Run via terminal

Run the script:

    ./dump.py /tmp/chainstate/ /tmp/

## Performance Report:

    Total iterations: 185966894
    Transactions decoded: 71000691
    Transactions not decoded: 114966203
    Records in final table 'balance': 30340045
    Speed (in seconds): 10895.994495868683



# SWIFT version

Contains *signed* dynamic libraries:

- libleveldb.1.dylib
- libsnappy.1.dylib
- libtcmalloc.4.dylib

Was compiled for *x86*.

Not tested under *ARM*.

Binary file cannot be run with *unsigned* dynamic libraries.

## Run binary via terminal

Install *signed* dynamic libraries:

    mkdir -p /usr/local/opt/leveldb/lib/
    cp libleveldb.1.dylib /usr/local/opt/leveldb/lib/

    mkdir -p /usr/local/opt/snappy/lib/
    cp libsnappy.1.dylib /usr/local/opt/snappy/lib/

    mkdir -p /usr/local/opt/gperftools/lib/
    cp libtcmalloc.4.dylib /usr/local/opt/gperftools/lib/

Run the binary:

    ./dump  /tmp/chainstate/ /tmp/

Prematurely canceling parsing process does not remove locks from LevelDB.

## Run source via xCode

Was created on Swift v.5+.

Depends on libraries (were built into the project):

- [https://github.com/anquii/RIPEMD160](url)
- [https://github.com/attaswift/BigInt](url)
- [https://github.com/stephencelis/SQLite.swift](url)
- [https://github.com/emilwojtaszek/leveldb-swift](url) (modified and adopted)

Go to `Edit Scheme... → Arguments → Arguments Passed on Launch` and change paths to *chainstate* and *report* if required.

Press the *start* button.

## Run Build Release via xCode

If you want to build a Release, run the `leveldb` installation:

    brew install leveldb

This command creates a set of files for dynamic libraries (header files and others).
This set will also contain the *unsigned* dynamic libraries.
*Unsigned* dynamic libraries can be copied to the project and will become *signed* after recompilation.

Go to `PROJECT Dump → Build Settings → Exclude Architectures → Release` and remove `arm64` on ARM platforms.

Then select menu `Product → Archive`.

Export *signed* binary file with *signed* dynamic libraries to favorite directory.

Binary file cannot be run with *unsigned* dynamic libraries.

## Performance Report:

    Total iterations: 185966894
    Transactions decoded: 71000691
    Transactions not decoded: 114966203
    Records in final table 'balance': 30340045
    Speed (in seconds): 12624.442268013954



# WIKI

Address types:

| Type   | First Seen | BTC Supply   | Useage     | Encoding | Prefix | Characters |
|:-------|:-----------|:-------------|:-----------|:---------|:-------|:-----------|
| P2PK   | Jan 2009   | 9% (1.7M)    | Obsolete   |          |        |            |
| P2PKH  | Jan 2009   | 43% (8.3M)   | Decreasing | Base58   | 1      | 26 – 34    |
| P2MS   | Jan 2012   | Negligible   | Obsolete   |          |        |            |
| P2SH   | Apr 2012   | 24% (4.6M)   | Decreasing | Base58   | 3      | 34         |
| P2WPKH | Aug 2017   | 20% (3.8M)   | Increasing | Bech32   | bc1q   | 42         |
| P2WSH  | Aug 2017   | 4% (0.8M)    | Increasing | Bech32   | bc1q   | 62         |
| P2TR   | Nov 2021   | 0.1% (0.02M) | Increasing | Bech32m  | bc1p   | 62         |


