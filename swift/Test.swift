
import Foundation

class Test {

    //  privWIF    : Private Key WIF (51 characters base58, starts with a "5")
    //  privWIFComp: Private Key WIF Compressed (52 characters base58, starts with a "K" or "L")
    //  privHex    : Private Key Hexadecimal Format (64 characters [0-9A-F])
    //  privBase64 : Private Key Base64 (44 characters)
    //  ---------------------------------------------------------------------------
    //  pub        : Public Key (130 characters [0-9A-F])
    //  pubComp    : Public Key Compressed (66 characters [0-9A-F])
    //  ---------------------------------------------------------------------------
    //  address    : Bitcoin P2PKH Address
    //  addressComp: Bitcoin P2PKH Address Compressed

    static let etaloneWallet = (
        privWIF     : "5KaAT2c5GYRSYPjkpyyuMsw26u9pjzZwdcTVE9FmiDmXV1rnVpw",
        privWIFComp : "L4yNht5oqbgsjZMiSnWA79oRs3Bwim6Q8bVub1SCLwMXYSnbzeDA",
        privHex     : "e753037ec3234a348c58538045e9d051a3035b1301c828761b1c9c98e8bb7012",
        privBase64  : "51MDfsMjSjSMWFOARenQUaMDWxMByCh2GxycmOi7cBI=",
        pub         : "048aab35f156b925897c15e2f9d39945d31fa1a8902141613aa9e8c415e15b61511e770aea975b45c655c1825ed5106d970e818f40abacbe1c98f74e155e4c5d3a",
        pubComp     : "028aab35f156b925897c15e2f9d39945d31fa1a8902141613aa9e8c415e15b6151",
        address     : "1MDzbe9oQvyBVY9wiexAJBwsp6ftTfA4Yg",
        addressComp : "1Pn3uQjHYdovztpHJzF41ALUVYtPFAaY4a",
        privKeyData : Data([
            231, 83, 3, 126, 195, 35, 74, 52, 140, 88, 83, 128, 69, 233, 208, 81,
            163, 3, 91, 19, 1, 200, 40, 118, 27, 28, 156, 152, 232, 187, 112, 18
        ])
    )

    static let etaloneTransaction = (
        TX       : "43000003502797e99d1cc6f9497253b2290514fdf647e12487c20c4b20e3833e0300",
        Coin     : "b98276a2ec7700cbc2986ff9aed6825920aece14aa6f5382ca5580",
        TXID     : "033e83e3204b0cc28724e147f6fd140529b2537249f9c61c9de9972750030000",
        Script   : "cbc2986ff9aed6825920aece14aa6f5382ca5580",
        TXIndex  : 0,
        Height   : 475387,
        Coinbase : 0,
        Amount   : 65279
    )

    static func dataHex() -> Bool {

        let privKeyData = Test.etaloneWallet.privKeyData
        let privHex     = Test.etaloneWallet.privHex
        if Data(privKeyData        ) .hexEncodedString() != privHex {return false}
        if Data(hexEncoded: privHex)?.hexEncodedString() != privHex {return false}
        if Data(hexEncoded: "00"   )?.hexEncodedString() != "00"    {return false}
        if Data(hexEncoded: "0f"   )?.hexEncodedString() != "0f"    {return false}
        if Data(hexEncoded: "f0"   )?.hexEncodedString() != "f0"    {return false}
        if Data(hexEncoded: "ff"   )?.hexEncodedString() != "ff"    {return false}
        if Data(hexEncoded: "a"    )?.hexEncodedString() != nil     {return false}
        if Data(hexEncoded: "aX"   )?.hexEncodedString() != nil     {return false}
        if Data(hexEncoded: "Xa"   )?.hexEncodedString() != nil     {return false}
        if Data(hexEncoded: "XX"   )?.hexEncodedString() != nil     {return false}

        // test long hex value
        let longHex =
            "00010203040506070809" + "0a0b0c0d0e0f10111213" + "1415161718191a1b1c1d" +
            "1e1f2021222324252627" + "28292a2b2c2d2e2f3031" + "32333435363738393a3b" +
            "3c3d3e3f404142434445" + "464748494a4b4c4d4e4f" + "50515253545556575859" +
            "5a5b5c5d5e5f60616263" + "6465666768696a6b6c6d" + "6e6f7071727374757677" +
            "78797a7b7c7d7e7f8081" + "82838485868788898a8b" + "8c8d8e8f909192939495" +
            "969798999a9b9c9d9e9f" + "a0a1a2a3a4a5a6a7a8a9" + "aaabacadaeafb0b1b2b3" +
            "b4b5b6b7b8b9babbbcbd" + "bebfc0c1c2c3c4c5c6c7" + "c8c9cacbcccdcecfd0d1" +
            "d2d3d4d5d6d7d8d9dadb" + "dcdddedfe0e1e2e3e4e5" + "e6e7e8e9eaebecedeeef" +
            "f0f1f2f3f4f5f6f7f8f9" + "fafbfcfdfeff"
        var longData = Data()
        for value in 0...255 {
            longData.append(
                UInt8(value)
            )
        }
        guard longData.hexEncodedString() == longHex else {
            return false
        }

        return true
    }

    static func runForCore() -> Bool {
        guard Test.dataHex() else {return false}
        return true
    }

    // ############################################################

    static func parseBase128() -> Bool {
        let (parseResult1, parseOffset1) = ChainstateParser.parseBase128(data: Data(hexEncoded: Test.etaloneTransaction.Coin)!, offset: 0)
        let (parseResult2, parseOffset2) = ChainstateParser.parseBase128(data: Data(hexEncoded: Test.etaloneTransaction.Coin)!, offset: parseOffset1)
        let (parseResult3, parseOffset3) = ChainstateParser.parseBase128(data: Data(hexEncoded: Test.etaloneTransaction.Coin)!, offset: parseOffset2)
        if parseResult1.hexEncodedString() != "b98276" {return false}
        if parseResult2.hexEncodedString() != "a2ec77" {return false}
        if parseResult3.hexEncodedString() != "00"     {return false}
        if parseOffset1                    != 3        {return false}
        if parseOffset2                    != 6        {return false}
        if parseOffset3                    != 7        {return false}
        return true
    }

    static func decompressAmount() -> Bool {
        if ChainstateParser.decompressAmount(0)      != 0     {return false}
        if ChainstateParser.decompressAmount(587511) != 65279 {return false}
        return true
    }

    static func encodeVarInt() -> Bool {
        for value in 0...10_000 {
            let valueToData = ChainstateParser.encodeVarInt(value)
            let dataToValue = ChainstateParser.decodeVarInt(valueToData)
            if value != dataToValue {
                return false
            }
        }
        return true
    }

    static func decodeVarInt() -> Bool {
        if ChainstateParser.decodeVarInt(Data(hexEncoded: "b98276")!) != 950774 {return false}
        if ChainstateParser.decodeVarInt(Data([185, 130, 118]))       != 950774 {return false}
        return true
    }

    static func decodeUTXO() -> Bool {
        let parser = ChainstateParser()
        let utxoInfo = parser.parse(
            tx  : Data(hexEncoded: Test.etaloneTransaction.TX)!,
            coin: Data(hexEncoded: Test.etaloneTransaction.Coin)!
        )
        if utxoInfo                            == nil                              {return false}
        if utxoInfo!.txId                      != Test.etaloneTransaction.TXID     {return false}
        if utxoInfo!.txIndex                   != Test.etaloneTransaction.TXIndex  {return false}
        if utxoInfo!.height                    != Test.etaloneTransaction.Height   {return false}
        if utxoInfo!.coinbase                  != Test.etaloneTransaction.Coinbase {return false}
        if utxoInfo!.amount                    != Test.etaloneTransaction.Amount   {return false}
        if utxoInfo!.script.hexEncodedString() != Test.etaloneTransaction.Script   {return false}
        return true
    }

    static func decompressPublicKey() -> Bool {
        let pubKey = ChainstateParser.decompressPublicKey(key: Data(hexEncoded: Test.etaloneWallet.pubComp)!)
        return pubKey.hexEncodedString() == Test.etaloneWallet.pub
    }

    static func runForCrypto() -> Bool {
        guard Test.parseBase128()        else {return false}
        guard Test.decompressAmount()    else {return false}
        guard Test.encodeVarInt()        else {return false}
        guard Test.decodeVarInt()        else {return false}
        guard Test.decodeUTXO()          else {return false}
        guard Test.decompressPublicKey() else {return false}
        return true
    }

}
