"""Henter fisketabellene ut av CMaNGOS Classic-databasen til fish_raw.json (kjøres i en arbeidsmappe).

    curl -L -o classicdb.sql.gz https://raw.githubusercontent.com/cmangos/classic-db/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz
    curl -L -o areatable.csv "https://wago.tools/db2/AreaTable/csv?product=wow_classic_era"
    python <repo>/tools/extract_fish.py
    python <repo>/tools/build_fishdata.py fish_raw.json areatable.csv
"""
import gzip
import json
import re

TABLES = {"fishing_loot_template": [], "reference_loot_template": [], "item_template": []}


def split_fields(t):
    out, cur, q, i = [], "", False, 0
    while i < len(t):
        c = t[i]
        if q:
            if c == "\\" and i + 1 < len(t):
                cur += t[i + 1]
                i += 2
                continue
            if c == "'":
                q = False
            else:
                cur += c
        else:
            if c == "'":
                q = True
            elif c == ",":
                out.append(cur)
                cur = ""
            else:
                cur += c
        i += 1
    out.append(cur)
    return out


def parse_values(body):
    """(a,'b,(c)',d),(…) → [[a, 'b,(c)', d], …] – parenteser og komma inne i strenger teller ikke."""
    rows, fields, cur, q, inside, i = [], [], "", False, False, 0
    while i < len(body):
        c = body[i]
        if q:
            if c == "\\" and i + 1 < len(body):
                cur += body[i + 1]
                i += 2
                continue
            if c == "'":
                q = False
            else:
                cur += c
        elif c == "'":
            q = True
        elif c == "(" and not inside:
            inside, fields, cur = True, [], ""
        elif c == ")" and inside:
            fields.append(cur)
            rows.append(fields)
            inside = False
        elif c == "," and inside:
            fields.append(cur)
            cur = ""
        elif inside:
            cur += c
        i += 1
    return rows


item_cols = None
with gzip.open("classicdb.sql.gz", "rt", encoding="utf-8", errors="replace") as f:
    in_item_create = False
    cols = []
    for line in f:
        if line.startswith("CREATE TABLE `item_template`"):
            in_item_create = True
            cols = []
            continue
        if in_item_create:
            m = re.match(r"\s+`(\w+)`", line)
            if m:
                cols.append(m.group(1))
            if line.startswith(")"):
                in_item_create = False
                item_cols = cols
            continue
        for name in TABLES:
            if line.startswith("INSERT INTO `%s` VALUES " % name):
                body = line[len("INSERT INTO `%s` VALUES " % name):].rstrip()
                TABLES[name].extend(parse_values(body))

ii, ni, qi, ci = item_cols.index("entry"), item_cols.index("name"), item_cols.index("Quality"), item_cols.index("class")
items = {}
for r in TABLES["item_template"]:
    items[int(r[ii])] = {"name": r[ni], "quality": int(r[qi]), "class": int(r[ci])}


def rows(t):
    return [{"entry": int(r[0]), "item": int(r[1]), "chance": float(r[2]), "group": int(r[3]),
             "ref": int(r[4]), "max": int(r[5]), "cond": int(r[6]), "comment": r[7]} for r in TABLES[t]]


out = {"fishing": rows("fishing_loot_template"), "reference": rows("reference_loot_template"),
       "items": {}}
used = set(r["item"] for r in out["fishing"]) | set(r["item"] for r in out["reference"])
out["items"] = {str(k): v for k, v in items.items() if k in used}
json.dump(out, open("fish_raw.json", "w", encoding="utf-8"))
print(len(out["fishing"]), "fiske-rader,", len(out["reference"]), "referanse-rader,", len(out["items"]), "ting")
