-- Alle UI-tekster i Skitt Fiske (norsk bokmål)
local addonName, ns = ...

ns.L = {
  TITLE = "Skitt Fiske",
  MACRO_NAME = "Skitt Fiske",

  -- Chat
  PREFIX = "|cff4fb3d9Skitt Fiske:|r ",
  MACRO_MADE = "makroen «Skitt Fiske» er laget. Skriv /skitt makro, så ligger den på musa – klikk den på en plass på baren.",
  MACRO_FULL = "fikk ikke laget makroen (fullt?). Lag en selv med teksten /skitt.",
  MACRO_ON_CURSOR = "makroen ligger på musa – klikk den på en plass på baren.",
  NO_POLE = "du har ingen fiskestang i baggen.",
  IN_COMBAT_START = "ikke midt i kamp.",
  IN_COMBAT_RESTORE = "våpnene er på. Resten av utstyret kommer på når kampen er over.",
  RESTORED_LATER = "utstyret ditt er på igjen.",
  MISSING_ITEM = "fant ikke %s i baggen – den må tas på for hånd.",
  NO_SPACE = "ingen ledig plass i baggen til %s.",
  AGGRO = "du er i kamp! Trykk Skitt Fiske for å få våpnene tilbake.",
  NO_REPORT = "ingen fangstrapporter ennå.",
  HELP = "/skitt – start eller avslutt fisking · /skitt makro · /skitt rapport · /skitt debug",

  -- Vinduet
  SKILL = "Fiske %d/%d",
  SKILL_BONUS = "  |cff7fd47f+%d|r",
  SKILL_UNKNOWN = "Fiske",
  LURE_NONE = "Uten agn",
  LURE_LEFT = "Agn %s",
  LURE_NONE_IN_BAGS = "Ingen agn i baggen",
  LURE_PICK = "Velg agn",
  CATCH_EMPTY = "Ingen fangst ennå",
  CATCH_ROW = "%d × %s",
  STATS = "Kast %d · Fanget %d",
  STATS_ESCAPED = " · Slapp unna %d",
  HINT = "Dobbelt høyreklikk: kast  ·  Høyreklikk på duppen: fang",
  COMBAT_WARN = "I kamp – trykk Skitt Fiske for våpnene",

  -- Rapporten
  REPORT_TITLE = "Fangsten",
  REPORT_WHEN = "%s · %s",
  REPORT_TIME = "Tid",
  REPORT_CASTS = "Kast",
  REPORT_CAUGHT = "Fanget",
  REPORT_ESCAPED = "Slapp unna",
  REPORT_MISSED = "For tidlig/sent",
  REPORT_SKILL = "Fiske",
  REPORT_SKILL_VALUE = "%d → %d  (+%d)",
  REPORT_VALUE = "Verdi",
  REPORT_PER_HOUR = "Per time",
  REPORT_MONEY = "Penger",
  REPORT_NOTHING = "Ingenting på kroken denne gangen.",
  REPORT_SOURCE = "Verdi: normalkurs fra Sparkmack etter AH-avgift, ellers det vendoren betaler.",
  REPORT_SOURCE_VENDOR = "Verdi: det vendoren betaler.",
  REPORT_PAGE = "%d av %d",
  REPORT_CLOSE = "Lukk",
  REPORT_ESCAPED_HINT = "Mange slapp unna: fiskeskillen er for lav for dette vannet.",

  -- Tid og penger
  DUR_S = "%d s",
  DUR_M = "%d min",
  DUR_HM = "%d t %d min",
  LEFT_S = "%d s",
  LEFT_M = "%d min",
}
