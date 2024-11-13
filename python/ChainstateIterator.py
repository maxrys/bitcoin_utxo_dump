from binascii import unhexlify
from leveldb import LevelDB  # pip3 install amulet-leveldb

class ChainstateIterator:

    def __init__(self, path):
        self.path = path
        # Set connection.
        try:
            self.connection = LevelDB(path, create_if_missing=False)
        except Exception as error:
            raise Exception(f"LevelDB Connection Error: {error}")
        # Set "obfuscateKey".
        try:
            obfuscateKey = self.connection.get("\x0e\x00obfuscate_key".encode())
            self.obfuscateKey = obfuscateKey[1:]
        except:
            self.obfuscateKey = None

    def getObfuscateKey(self):
        return self.obfuscateKey

    def values(self):
        return self.connection.iterate()

    def valuesByTransaction(self, txId, index = None):
        key = b"\x43" + bytes(reversed(unhexlify(txId.encode())))
        if index != None:
            try:
                fullKey = key + ChainstateParser.encodeVarInt(index)
                value = self.connection.get(fullKey)
                if value:
                    yield fullKey, value
            except:
                pass
        else:
            i = 0
            attempts = 0
            while True:
                if attempts >= 3:
                    break
                try:
                    fullKey = key + ChainstateParser.encodeVarInt(i)
                    value = self.connection.get(fullKey)
                    if value:
                        yield fullKey, value
                except:
                    attempts += 1
                i += 1

    def finalize(self):
        self.connection.close()
