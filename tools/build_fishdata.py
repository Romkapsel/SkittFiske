"""Lager FishData.lua: hva som kan fanges i hvert område, med sjanse per fangst.

    python tools/build_fishdata.py <fish_raw.json> <AreaTable.csv>

Kilde: CMaNGOS Classic-databasen (https://github.com/cmangos/classic-db, GPL-3): fishing_loot_template og
reference_loot_template, hentet ut av tools/extract_fish.py (i scratchpad 7. okt). Områdenavn fra AreaTable
(wago.tools, wow_classic_era). Nøkkelen er som i SkittFiskeDB.zones: «Sone» eller «Sone / Underområde».
Sjansen: grupper deler 100 % (rader uten sjanse deler resten likt), rader utenfor grupper er uavhengige.
"""
import csv
import json
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN_PCT = 0.5  # sjeldnere enn dette tas ikke med


def load(raw_path, area_path):
    raw = json.load(open(raw_path, encoding="utf-8"))
    areas = {}
    with open(area_path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            areas[int(r["ID"])] = (r["AreaName_lang"], int(r["ParentAreaID"] or 0))
    return raw, areas


def expand(rows_by_entry, entry, mult, out, depth=0):
    rows = rows_by_entry.get(entry, [])
    if depth > 6:
        return
    groups = defaultdict(list)
    for r in rows:
        if r["chance"] < 0:  # oppdragsting
            continue
        groups[r["group"]].append(r)
    for g, rs in groups.items():
        if g == 0:
            probs = [(r, r["chance"] / 100.0) for r in rs]
        else:
            explicit = sum(r["chance"] for r in rs if r["chance"] > 0)
            zero = [r for r in rs if r["chance"] == 0]
            rest = max(0.0, 100.0 - explicit) / len(zero) if zero else 0
            probs = [(r, (r["chance"] if r["chance"] > 0 else rest) / 100.0) for r in rs]
        for r, p in probs:
            if r["ref"] < 0:
                expand(rows_by_entry["__ref__"], -r["ref"], mult * p, out, depth + 1)
            else:
                out[r["item"]] += mult * p


def main():
    raw, areas = load(sys.argv[1], sys.argv[2])
    fishing = defaultdict(list)
    for r in raw["fishing"]:
        fishing[r["entry"]].append(r)
    refs = defaultdict(list)
    for r in raw["reference"]:
        refs[r["entry"]].append(r)
    fishing["__ref__"] = refs
    items = raw["items"]

    data = {}
    for entry in sorted(k for k in fishing if k != "__ref__"):
        if entry not in areas:
            continue
        name, parent = areas[entry]
        key = name if parent == 0 else "%s / %s" % (areas.get(parent, ("?", 0))[0], name)
        probs = defaultdict(float)
        expand(fishing, entry, 1.0, probs)
        rows = [(i, p) for i, p in probs.items() if p * 100 >= MIN_PCT and str(i) in items]
        rows.sort(key=lambda x: -x[1])
        if rows:
            data[key] = rows

    lines = [
        "-- Hva som kan fanges i hvert område (sjanse per fangst, 0–1). Laget av tools/build_fishdata.py – ikke rediger for hånd.",
        "-- Kilde: CMaNGOS Classic-databasen (github.com/cmangos/classic-db, GPL-3), Classic 1.12. Nøkkel: «Sone» eller «Sone / Underområde».",
        "local addonName, ns = ...",
        "",
        "ns.FishData = {",
        "  zones = {",
    ]
    used = set()
    for key in sorted(data):
        parts = ", ".join("{ %d, %.4f }" % (i, p) for i, p in data[key])
        lines.append('    ["%s"] = { %s },' % (key.replace('"', '\\"'), parts))
        used.update(i for i, _ in data[key])
    lines.append("  },")
    lines.append("  -- Fiskenivået i området (skill_fishing_base_level). Sjanse = skill − nivå + 5 %, ingenting under nivået,")
    lines.append("  -- ingen slipper unna fra nivå + 95 (CMaNGOS GameObject.cpp). Skill fra utstyr og agn teller med.")
    lines.append("  skill = {")
    for area_id, base in sorted(raw.get("skill", {}).items(), key=lambda kv: int(kv[0])):
        area_id = int(area_id)
        if area_id not in areas:
            continue
        name, parent = areas[area_id]
        key = name if parent == 0 else "%s / %s" % (areas.get(parent, ("?", 0))[0], name)
        lines.append('    ["%s"] = %d,' % (key.replace('"', '\\"'), base))
    lines.append("  },")
    lines.append("  -- Navn til ting spillet ikke har lastet ennå (engelsk, som klienten)")
    lines.append("  names = {")
    for i in sorted(used):
        lines.append('    [%d] = "%s",' % (i, items[str(i)]["name"].replace('"', '\\"')))
    lines.append("  },")
    lines.append("}")
    path = os.path.join(ROOT, "FishData.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(len(data), "områder,", len(used), "ting ->", path)
    for k in ("Elwynn Forest", "Stormwind City", "Stormwind City / The Canals", "Durotar", "Stranglethorn Vale"):
        if k in data:
            print(k, [(items[str(i)]["name"], round(p * 100, 1)) for i, p in data[k][:6]])
        else:
            print(k, "– mangler")


if __name__ == "__main__":
    main()
