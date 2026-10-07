"""Kjører alle testene for Skitt Fiske i Lua 5.1 (lupa).

    python tests/run.py

- tests/test_*.lua  Logic.lua i en helt tom Lua uten WoW-API (beviser at den er ren)
- tests/mock_*.lua  hele addonen (alle filer i TOC) mot en falsk WoW-klient (tests/mock_wow.lua)
I tillegg sjekkes kildekoden: bakstreker i strenger, at TOC-filene finnes, interface 16001, og ingen nye globale.
"""
import os
import re
import sys

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "tests")
TOC = os.path.join(ROOT, "SkittFiske.toc")
ALLOWED_GLOBALS = {"SkittFiskeDB", "SkittFiskeCharDB", "SLASH_SKITTFISKE1", "SLASH_SKITTFISKE2"}

failures = 0
passes = 0


def read(p):
    with open(p, "rb") as f:
        return f.read().decode("utf-8")


def toc_files():
    files = []
    for line in read(TOC).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(line.replace("\\", os.sep))
    return files


def check(ok, what):
    global failures, passes
    if ok:
        passes += 1
    else:
        failures += 1
        print("FEIL:", what)


def source_checks():
    toc = read(TOC)
    check("## Interface: 16001" in toc, "TOC: interface 16001")
    for rel in toc_files():
        p = os.path.join(ROOT, rel)
        check(os.path.exists(p), "TOC-fil finnes: " + rel)
        if not os.path.exists(p):
            continue
        src = read(p)
        # Bakstrek i en streng må være \\, \n, \t, \" eller \' – ellers blir en sti som Interface\Icons ødelagt
        for n, line in enumerate(src.splitlines(), 1):
            if line.lstrip().startswith("--"):
                continue
            bad = [m for m in re.finditer(r"\\(.)", line) if m.group(1) not in "\\nt\"'"]
            if bad:
                check(False, f"{rel}:{n}: enkel bakstrek: {line.strip()}")
        check("\t" not in src, rel + ": ingen tab-tegn")
        # Bildene koden bruker, finnes i Media/ og har sider i toerpotens
        for name in set(re.findall(r'"(\w+\.tga)"', src)):
            mp = os.path.join(ROOT, "Media", name)
            check(os.path.exists(mp), f"{rel}: Media/{name} finnes")
            if os.path.exists(mp):
                with open(mp, "rb") as fh:
                    head = fh.read(18)
                w, h = head[12] | head[13] << 8, head[14] | head[15] << 8
                check(w & (w - 1) == 0 and h & (h - 1) == 0, f"Media/{name}: {w}x{h} er toerpotens")


def new_runtime():
    return lua51.LuaRuntime(unpack_returned_tuples=True)


def load_into(lua, path, *args):
    chunk = lua.execute("return function(src, name) return assert(loadstring(src, '@' .. name)) end")(read(path), os.path.relpath(path, ROOT))
    return chunk(*args)


def run_pure(test):
    lua = new_runtime()
    ns = lua.table()
    lua.globals().NS = ns
    load_into(lua, os.path.join(ROOT, "Locale", "nbNO.lua"), "SkittFiske", ns)
    load_into(lua, os.path.join(ROOT, "Data.lua"), "SkittFiske", ns)
    load_into(lua, os.path.join(ROOT, "Logic.lua"), "SkittFiske", ns)
    return run_test(lua, test)


def run_mock(test):
    lua = new_runtime()
    load_into(lua, os.path.join(TESTS, "mock_wow.lua"))
    lua.execute("BASELINE = {} for k in pairs(_G) do BASELINE[k] = true end")
    lua.globals().ALLOWED = lua.table_from({k: True for k in ALLOWED_GLOBALS})

    # LoadAddon() laster alle filene i TOC på nytt med et nytt ns (som /reload); SavedVariables blir liggende
    def load_addon():
        ns = lua.table()
        lua.globals().NS = ns
        for rel in toc_files():
            load_into(lua, os.path.join(ROOT, rel), "SkittFiske", ns)
        return ns

    lua.globals().LoadAddon = load_addon
    load_addon()
    return run_test(lua, test)


def run_test(lua, test):
    global failures, passes
    lua.execute("""
      RESULTS = { pass = 0, fail = {} }
      function check(ok, what) if ok then RESULTS.pass = RESULTS.pass + 1 else table.insert(RESULTS.fail, what) end end
    """)
    name = os.path.basename(test)
    try:
        load_into(lua, test)
    except Exception as e:  # noqa: BLE001
        failures += 1
        print(f"FEIL: {name} krasjet: {e}")
        return
    r = lua.globals().RESULTS
    passes += r["pass"]
    for i in range(1, len(r["fail"]) + 1):
        failures += 1
        print(f"FEIL: {name}: {r['fail'][i]}")
    print(f"  {name}: {r['pass']} ok, {len(r['fail'])} feil")


def main():
    source_checks()
    for f in sorted(os.listdir(TESTS)):
        p = os.path.join(TESTS, f)
        if f.startswith("test_") and f.endswith(".lua"):
            run_pure(p)
        elif f.startswith("mock_") and f.endswith(".lua") and f != "mock_wow.lua":
            run_mock(p)
    print(f"{passes}/{passes + failures} ok")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
