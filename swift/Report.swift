
import Foundation
import SQLite

class Report {

    enum mode {
        case dumpBalance
        case dumpTransactions
        case dumpBadTransactions
    }

    private let file: String
    private let connection: Connection
    private let modes: Set<mode>

    private var balance_insertStmt: Statement?
    private var balance_updateStmt: Statement?
    private var transactions_insertStmt: Statement?
    private var badTransactions_insertStmt: Statement?

    init(file: String, modes: Set<mode> = [.dumpBalance]) throws {
        self.file = file
        // Set connection.
        self.connection = try Connection(file)
        // Set modes.
        self.modes = modes
        // Initialization of "balance".
        if self.modes.contains(.dumpBalance) {
            try self.connection.prepare("DROP TABLE IF EXISTS `balance`;").run()
            try self.connection.prepare("""
                CREATE TABLE `balance` (
                    `address`    TEXT    NOT NULL COLLATE BINARY PRIMARY KEY,
                    `amount`     INTEGER NOT NULL DEFAULT(0),
                    `max_height` INTEGER NOT NULL DEFAULT(0)
                );
            """).run()
            try self.connection.prepare("CREATE INDEX `balance__amount`              ON `balance`(`amount`);"              ).run()
            try self.connection.prepare("CREATE INDEX `balance__max_height`          ON `balance`(`max_height`);"          ).run()
            try self.connection.prepare("CREATE INDEX `balance__amount___max_height` ON `balance`(`amount`, `max_height`);").run()
            self.balance_insertStmt = try self.connection.prepare("""
                INSERT OR IGNORE INTO `balance` (`address`, `amount`, `max_height`)
                VALUES (?, ?, ?);
            """)
            self.balance_updateStmt = try self.connection.prepare("""
                UPDATE `balance`
                SET `amount` = `amount` + ?, `max_height` = max(`max_height`, ?)
                WHERE `address` = ?;
            """)
        }
        // Initialization of "transactions".
        if self.modes.contains(.dumpTransactions) {
            try self.connection.prepare("DROP TABLE IF EXISTS `transactions`;").run()
            try self.connection.prepare("""
                CREATE TABLE `transactions` (
                    `txid`    TEXT    NOT NULL COLLATE BINARY,
                    `address` TEXT    NOT NULL COLLATE BINARY,
                    `amount`  INTEGER NOT NULL DEFAULT(0),
                    `height`  INTEGER NOT NULL DEFAULT(0)
                );
            """).run()
            try self.connection.prepare("CREATE INDEX `transactions__txid`    ON `transactions`(`txid`);"   ).run()
            try self.connection.prepare("CREATE INDEX `transactions__address` ON `transactions`(`address`);").run()
            self.transactions_insertStmt = try self.connection.prepare("""
                INSERT INTO `transactions` (`txid`, `address`, `amount`, `height`)
                VALUES (?, ?, ?, ?);
            """)
        }
        // Initialization of "bad_transactions".
        if self.modes.contains(.dumpBadTransactions) {
            try self.connection.prepare("DROP TABLE IF EXISTS `bad_transactions`;").run()
            try self.connection.prepare("""
                CREATE TABLE `bad_transactions` (
                    `txid`   TEXT    NOT NULL COLLATE BINARY,
                    `amount` INTEGER NOT NULL DEFAULT(0),
                    `height` INTEGER NOT NULL DEFAULT(0)
                );
            """).run()
            try self.connection.prepare("CREATE INDEX `bad_transactions__txid` ON `bad_transactions`(`txid`);").run()
            self.badTransactions_insertStmt = try self.connection.prepare("""
                INSERT INTO `bad_transactions` (`txid`, `amount`, `height`)
                VALUES (?, ?, ?);
            """)
        }
        try self.connection.prepare("BEGIN TRANSACTION;").run()
    }

    func append(txId: String, amount: Int, height: Int, address: String) throws {
        if self.modes.contains(.dumpBalance) {
            if self.balance_insertStmt != nil && address != "" {
                try self.balance_insertStmt!.run(address, 0, 0)
            }
            if self.balance_updateStmt != nil && address != "" {
                try self.balance_updateStmt!.run(amount, height, address)
            }
        }
        if self.modes.contains(.dumpTransactions) {
            if self.transactions_insertStmt != nil && address != "" {
                try self.transactions_insertStmt!.run(txId, address, amount, height)
            }
        }
        if self.modes.contains(.dumpBadTransactions) {
            if self.badTransactions_insertStmt != nil {
                try self.badTransactions_insertStmt!.run(txId, amount, height)
            }
        }
    }

    func finalize() throws -> (balance: Binding?, transactions: Binding?, badTransactions: Binding?) {
        try self.connection.prepare("COMMIT TRANSACTION;").run()
        var balanceBinding: Binding?
        var transactionsBinding: Binding?
        var badTransactionsBinding: Binding?
        if self.modes.contains(.dumpBalance        ) {balanceBinding         = try self.connection.scalar("SELECT count(*) as `count` FROM `balance`;")}
        if self.modes.contains(.dumpTransactions   ) {transactionsBinding    = try self.connection.scalar("SELECT count(*) as `count` FROM `transactions`;")}
        if self.modes.contains(.dumpBadTransactions) {badTransactionsBinding = try self.connection.scalar("SELECT count(*) as `count` FROM `bad_transactions`;")}
        return (
            balance        : balanceBinding,
            transactions   : transactionsBinding,
            badTransactions: badTransactionsBinding
        )
    }

}
