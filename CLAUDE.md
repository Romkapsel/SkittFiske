# Skitt Fiske – WoW Forever-addon

Fiske-addon for WoW Forever. Eier: Daniel (snakker norsk). Makroen «Skitt Fiske» (`/skitt`) på baren starter og avslutter:
fiskeutstyret på/av, lyden opp/tilbake, vinduet åpent/lukket, og en fangstrapport til slutt.

## Les først

1. `docs/HISTORIKK.md` – hva som er avgjort (§2), hva som må sjekkes i spillet (§3, V1–V8) og svarene derfra.
2. `README.md` – håndboka for spilleren.

## Regler

- **Alle skal kunne bruke den** (Daniel, «veldig viktig»): ingen navn, realmer, klasser eller stier i koden.
  Fangst og historikk per konto (`SkittFiskeDB`), utstyr og pågående økt per karakter (`SkittFiskeCharDB`).
  Sparkmack er valgfri: uten den brukes vendorprisen.
- **Aldri kast eller bruk noe automatisk.** Dobbelt høyreklikk binder høyre musknapp et øyeblikk til en sikker
  Fishing-knapp – spilleren klikker selv. Duppen klikkes alltid av spilleren.
- **Kamp:** sikre knapper (agn, kast) og vinduet (som har sikre barn) kan ikke vises, skjules, flyttes eller få
  attributter i kamp. Kø i `ns.Queue`, kjøres ved `PLAYER_REGEN_ENABLED`. Rustning kan ikke byttes i kamp; våpen kan.
- **Hemmelige verdier:** alt fra spillet går gjennom `Game.try` (pcall + `issecretvalue`).
- **Ingen globale** utenom `SkittFiskeDB`, `SkittFiskeCharDB`, `SLASH_SKITTFISKE1/2` og rammer med navn `SkittFiske*`.
  Skriv aldri til spillets egne globale (taint – se Control-historikken).
- **Bakstreker:** skriv Lua-filer med Write/Edit, ikke heredoc (heredoc spiser `\\` i stier, og en ødelagt sti krasjer
  klienten). `tests/run.py` stopper enkle bakstreker.
- UI-tekst på norsk i `Locale/nbNO.lua`. Kode og commit-meldinger på engelsk.
- `Logic.lua` er ren Lua uten WoW-API.

## Kommandoer

```
python tests/run.py    # alle tester (Lua 5.1 via lupa)
```

I spillet: `/skitt` (start/stopp), `/skitt makro` (makroen på musa), `/skitt rapport`, `/skitt debug`, `/skitt debug tøm`.

## Installasjon

`Documents\SkittFiske` er koblet inn i spillet med en junction:
`C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\SkittFiske` → `Documents\SkittFiske`.
Endringer i eksisterende filer: `/reload`. Ny fil i TOC eller ny addon: spillet må startes helt på nytt.
Svar fra spillet leses i `WTF\Account\<konto>\SavedVariables\SkittFiske.lua` (`SkittFiskeDB.debug`).

## Arbeidsform

Sjekk inn ofte med Daniel: kort rapport og én anbefalt vei videre. Commit lokalt; push, GitHub-repo og utgivelse bare med hans ja.
