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
- selecteerbare terminaltekst;
- duidelijke verbindings-, host- en operatorfouten;
- actuele regel, kolom en schermgrootte onderin;
- voorkeuren worden lokaal onthouden.

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
rechthoekige selectie en dezelfde plugins als op macOS.
