# Swift3270 voor Windows

Dit is de native Windows-port van Swift3270. De macOS-app blijft ongewijzigd; de
Windows-app staat bewust in een eigen Swift package.

## Wat werkt

- native Windows-venster via WinUI;
- verbinden en disconnecten zonder de app te sluiten;
- TLS, LU-naam, model 2 t/m 5 en oversize;
- volledig 24/32/43/27-regelig terminalscherm;
- Enter, Clear, Reset, Tab, Backtab, pijltjes, Insert en F1 t/m F12;
- tekst sturen naar het huidige 3270-veld;
- direct typen in het terminalvlak en fysieke F1 t/m F24 gebruiken;
- `Shift+F1` t/m `Shift+F12` voor PF13-PF24 en `Page Up`/`Page Down` voor PF7/PF8;
- knoppen voor PF1-PF24, PA1-PA3, Attn, SysReq, Erase EOF, FieldMark en Dup;
- selecteerbare terminaltekst, kopiëren en plakken met `Ctrl+C` en `Ctrl+V`;
- automatische login voor toepassing, userid en password;
- ondersteuning voor losse loginprompts en het gecombineerde CICS-aanmeldscherm;
- tijdelijke schermgeschiedenis van maximaal 50 verschillende schermen;
- automatische detectie van COBOL IGY-compilerfouten met links naar IBM-documentatie;
- duidelijke verbindings-, host- en operatorfouten;
- actuele regel, kolom en schermgrootte onderin;
- voorkeuren worden lokaal onthouden.

## Automatische login

Vul in de loginbalk een toepassing zoals `TSOT` of `COF1R1`, het userid en het
password in. Schakel daarna **Automatisch invullen + Enter** in. Swift3270
herkent onder andere:

- `Kies uw toepassing ==>`;
- `ENTER USERID -`;
- `ENTER PASSWORD:`;
- het gecombineerde CICS-scherm met `User-ID` en `Password/phrase`.

Elke stap wordt na 700 ms ingevuld en bevestigd. Bij het gecombineerde
CICS-scherm navigeert Swift3270 met Tab van userid naar password en drukt daarna
op Enter. Toepassing, userid en de schakelaar worden lokaal onthouden. Het
password blijft uitsluitend in het geheugen en moet na een herstart opnieuw
worden ingevuld.

## COBOL-foutdetectie

IGY-compilerfoutcodes op het actuele of teruggekeken scherm verschijnen als
knoppen onder de terminal. Klik op een code om de bijbehorende IBM-documentatie
op te zoeken. Dubbele codes worden maar één keer getoond, tot maximaal tien per
scherm.

## Benodigd

1. Windows 10 of 11 (64-bit).
2. Swift 6.2 of nieuwer voor het bouwen.
3. `ws3270.exe` uit de Windows-versie van x3270.

Zet `ws3270.exe` in `PATH`, of vul in de bovenste balk het volledige pad naar
het bestand in.

## Bouwen

Open PowerShell in de repository:

```powershell
cd Windows
swift test
swift build -c release
```

De app staat daarna onder `.build` als `Swift3270Windows.exe`. GitHub Actions
bouwt en test de Windows-versie automatisch en levert een zip als artifact.

## Architectuur

- `Swift3270WindowsCore`: platformonafhankelijke host-, scherm- en protocolcode;
- `Swift3270Windows`: WinUI-interface en sessiebeheer;
- `ws3270`: de officiële x3270 TN3270/TN3270E-engine.

De volgende port-stap is de pixelnauwkeurige gekleurde terminalgrid met
rechthoekige selectie, meerdere opgeslagen sessies en verdere gelijkwaardigheid
met de macOS-plugins.
