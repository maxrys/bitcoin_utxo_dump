//
//  EncryptorDecryptor.swift
//  LevelDB
//
//  Created by Krzysztof Kapitan on 22.02.2017.
//  Copyright © 2017 codesplice. All rights reserved.
//

import Foundation

public final class EncryptorDecryptor: Encoder, Decoder {
    private let key: String
    private let iv: String

    public convenience init() {
        self.init(
            key: "passwordpassword",
            iv: "drowssapdrowssap"
        )
    }

    public init(key: String, iv: String) {
        self.key = key
        self.iv = iv
    }

    public func decode(data: Data) -> Data {
        return data
    }

    public func encode(data: Data) -> Data {
        return data
    }
}
