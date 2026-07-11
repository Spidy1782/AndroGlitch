#!/usr/bin/env python3
"""Read the Google Services Framework (GSF) Android ID from a pulled gservices.db.

Pull the db first (device sqlite3 is often absent):
    adb root
    adb pull /data/data/com.google.android.gsf/databases/gservices.db

Then:
    python read-gsf-id.py gservices.db

Register the printed decimal ID at https://www.google.com/android/uncertified
if Play sign-in loops with an "uncertified device" error.
"""
import sqlite3, sys

if len(sys.argv) < 2:
    sys.exit("usage: python read-gsf-id.py <gservices.db>")
db = sys.argv[1]
c = sqlite3.connect(db)
rows = c.execute("select name, value from main where name like '%android_id%'").fetchall()
if not rows:
    print("No android_id rows (device may not have checked in with Google yet).")
for name, value in rows:
    print(f"{name} = {value}")
    try:
        dec = int(value)
        print(f"  decimal: {dec}")
        print(f"  hex    : {dec:x}")
    except (ValueError, TypeError):
        pass
