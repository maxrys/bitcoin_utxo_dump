#!/usr/bin/env python3

import sqlite3

fileDatabase = "/tmp/result.sqlite"
fileReport = "/tmp/report.txt"

processedCount = 0
report = open(fileReport, "w")
cursor = sqlite3.connect(fileDatabase).cursor()
result = cursor.execute("""
    SELECT `address`, `amount`, `max_height`
    FROM `balance`
    ORDER BY `address`;
""")

while True:
    try:
        address, amount, maxHeight = result.fetchone()
        report.write(f"{address},{amount},{maxHeight}\n")
        if processedCount > 0 and processedCount % 10_000 == 0:
            print(f"{processedCount} records were processed.")
        processedCount += 1
    except:
        report.close()
        cursor.close()
        print(f"Done")
        break