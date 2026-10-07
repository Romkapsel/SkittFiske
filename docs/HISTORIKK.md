# Skitt Fiske – historikk

## 1. Bakgrunn

7. okt 2026: Daniel ville ha en fiske-addon for WoW Forever. Navnet er hans: **Skitt Fiske**.

## 2. Avgjort (Daniel, 7. okt)

| Hva | Valg |
|---|---|
| Start/stopp | Én makro på baren (`/skitt`). Første trykk: alt fiskeutstyr på, vinduet åpnes. Andre trykk: det gamle utstyret tilbake. |
| Det gamle utstyret | Ingen liste: addonen husker hva som satt på hver plass før byttet (`SkittFiskeCharDB.saved`). |
| Vinduet | Skjult til du fisker. Krysset avslutter som makroen (vindu åpent = du fisker). |
| Kast og fangst | Dobbelt høyreklikk kaster (ett klikk ville kollidert med å snu kameraet). Høyreklikk på duppen fanger. Ingen automatisk klikking (botting). |
| Agn | Én knapp. Ett slags agn i baggen: klikket setter det på. Flere: de kommer opp og du velger. Lyser når agnet holder på å gå ut. |
| Lyd | Effekter opp, musikk og omgivelser av, og lyd også når spillet ikke er i fokus. Alt tilbake etterpå. |
| Rapport | Når du avslutter: tid, kast, fanget, slapp unna, skill, fangsten med verdi, verdi per time. De 20 siste lagres. |
| Verdi | Sparkmack-normalkurs etter 5 % AH-avgift hvis Sparkmack er installert, ellers vendorpris. Høyeste av de to. |
| Senere | Liste over hva som kan fanges i vannet du står ved. Fangst per sone samles allerede nå i `SkittFiskeDB.zones`. |

## 3. Må sjekkes i spillet (fase 0)

`/skitt debug` skriver svarene i chatten og lagrer dem i `SkittFiskeDB.debug` (SavedVariables).

| # | Spørsmål | Hvor svaret står |
|---|---|---|
| V1 | Laster addonen (interface 16001), og lages makroen? | chat ved første innlogging |
| V2 | Finner den stang og fiskeutstyr i baggen, og tas det på? | `debug.snapshot.gear` |
| V3 | Kommer et dobbelt høyreklikk fram (`WorldFrame` OnMouseDown), og kaster slippet via override-bindingen? | `counts.rightDown`, `armed`, `castClick`, `channel` |
| V4 | Fanger høyreklikk på duppen, og sier `IsFishingLoot()` ja? | `debug.loot[1].fishing` |
| V5 | Hvilke feilmeldinger kommer når fisken slipper unna eller du klikker for tidlig? | `debug.errors` |
| V6 | Setter agnknappen agnet på stanga (`/use item:ID` + `/use 16`), og leser `GetWeaponEnchantInfo` tiden? | `snapshot.lureOnPole` |
| V7 | Høres plasket når spillet ikke er i fokus (`Sound_EnableSoundWhenGameIsInBG`)? | Daniel |
| V8 | Kommer utstyret riktig tilbake, også skjold/off-hand og i kamp? | Daniel |

### Svar

| # | Svar | Dato / build |
|---|---|---|

## 4. Beslutningslogg

| Dato | Hva | Hvem |
|---|---|---|
| 2026-10-07 | Første test (Tannan, Forever): vinduet stoppet halvveis i `W.Create` (mellom agnknappen og teksten ved siden av; første feilmelding ikke sett), og alt etterpå feilet på nil. Rettet: ingen spillmaler (BackdropTemplate, UIPanelCloseButton, UIPanelButtonTemplate, highlight-tekstur) og bare fontene Control bruker; pynt går gjennom `ns.Safe` og skrives i `debug.ui` + chat; vinduet er skjult til det er ferdig bygget (`f.ready`). Testene nekter nå ukjente maler. | Daniel / Claude |
| 2026-10-07 | v0.1.0 bygget: makro, utstyr, lyd, dobbeltklikk-kast, agnknapp, fangsttelling, rapport, debug. 208 tester. | Daniel / Claude |
