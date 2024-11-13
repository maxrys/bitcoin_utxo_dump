import sqlite3

class Report:

    def __init__(self, file, modes):
        self.file = file
        # Set connection.
        self.connection = sqlite3.connect(file)
        self.cursor = self.connection.cursor()
        # Set modes.
        self.modes = modes
        # Initialization of "balance".
        if "isDumpBalance" in self.modes:
            self.cursor.execute("DROP TABLE IF EXISTS `balance`;")
            self.cursor.execute("""
                CREATE TABLE `balance` (
                    `address`    TEXT    NOT NULL COLLATE BINARY PRIMARY KEY,
                    `amount`     INTEGER NOT NULL DEFAULT(0),
                    `max_height` INTEGER NOT NULL DEFAULT(0)
                );""")
            self.cursor.execute("CREATE INDEX `balance__amount`              ON `balance`(`amount`);")
            self.cursor.execute("CREATE INDEX `balance__max_height`          ON `balance`(`max_height`);")
            self.cursor.execute("CREATE INDEX `balance__amount___max_height` ON `balance`(`amount`, `max_height`);")
        # Initialization of "transactions".
        if "isDumpTransactions" in self.modes:
            self.cursor.execute("DROP TABLE IF EXISTS `transactions`;")
            self.cursor.execute("""
                CREATE TABLE `transactions` (
                    `txid`    TEXT    NOT NULL COLLATE BINARY,
                    `address` TEXT    NOT NULL COLLATE BINARY,
                    `amount`  INTEGER NOT NULL DEFAULT(0),
                    `height`  INTEGER NOT NULL DEFAULT(0)
                );""")
            self.cursor.execute("CREATE INDEX `transactions__txid`    ON `transactions`(`txid`);")
            self.cursor.execute("CREATE INDEX `transactions__address` ON `transactions`(`address`);")
        # Initialization of "bad_transactions".
        if "isDumpBadTransactions" in self.modes:
            self.cursor.execute("DROP TABLE IF EXISTS `bad_transactions`;")
            self.cursor.execute("""
                CREATE TABLE `bad_transactions` (
                    `txid`   TEXT    NOT NULL COLLATE BINARY,
                    `amount` INTEGER NOT NULL DEFAULT(0),
                    `height` INTEGER NOT NULL DEFAULT(0)
                );""")
            self.cursor.execute("CREATE INDEX `bad_transactions__txid` ON `bad_transactions`(`txid`);")
        self.cursor.execute("BEGIN TRANSACTION;")

    def append(self, txId, amount, height, address):
        if "isDumpBalance" in self.modes and address != "":
            self.cursor.execute("""
                INSERT OR IGNORE INTO `balance` (`address`, `amount`, `max_height`)
                VALUES (?, ?, ?);
            """, (address, 0, 0))
            self.cursor.execute("""
                UPDATE `balance`
                SET `amount` = `amount` + ?, `max_height` = max(`max_height`, ?)
                WHERE `address` = ?;
            """, (amount, height, address))
        if "isDumpTransactions" in self.modes and address != "":
            self.cursor.execute("""
                INSERT INTO `transactions` (`txid`, `address`, `amount`, `height`)
                VALUES (?, ?, ?, ?);
            """, (txId, address, amount, height))
        if "isDumpBadTransactions" in self.modes:
            self.cursor.execute("""
                INSERT INTO `bad_transactions` (`txid`, `amount`, `height`)
                VALUES (?, ?, ?);
            """, (txId, amount, height))

    def finalize(self):
        self.cursor.execute("COMMIT TRANSACTION;")
        countBalance         = self.cursor.execute("SELECT count(*) as `count` FROM `balance`;"         ).fetchone()[0] if "isDumpBalance"         in self.modes else 0
        countTransactions    = self.cursor.execute("SELECT count(*) as `count` FROM `transactions`;"    ).fetchone()[0] if "isDumpTransactions"    in self.modes else 0
        countBadTransactions = self.cursor.execute("SELECT count(*) as `count` FROM `bad_transactions`;").fetchone()[0] if "isDumpBadTransactions" in self.modes else 0
        self.cursor.close()
        return countBalance, countTransactions, countBadTransactions
