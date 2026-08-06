# Swift3270

Swift3270 is een native 3270-terminal voor macOS. De app gebruikt de betrouwbare `b3270`-backend van x3270, met een moderne SwiftUI-interface.

## Functies

- Meerdere opgeslagen sessies
- TLS, LU-naam en verschillende codepages
- Automatisch schalen en meerdere terminalmodellen
- PF1-PF24, PA1-PA3 en een optioneel toetsenpaneel
- Zoeken met `Cmd+F`
- Selecteren, dubbelklikken, kopiëren en plakken
- Scrollen met twee vingers
- Twee sessies naast elkaar met Developer Split
- Tijdelijke schermgeschiedenis
- Plugins en aanpasbare interfacekleuren
- Automatische updates via GitHub Releases

## Vereisten

- macOS 13 of nieuwer
- x3270 met `b3270`

Installeer x3270 met Homebrew:

```bash
brew install x3270
```

## Installeren

Download `Swift3270-macOS.zip` bij [GitHub Releases](https://github.com/prosir/Swift3270/releases), pak het bestand uit en verplaats `Swift3270.app` naar de map Programma's.

Omdat de app nog niet door Apple is ondertekend, kan macOS bij de eerste start een waarschuwing tonen. Open de app dan met rechtermuisknop → **Open**.

## Zelf bouwen

Swift 5.9 of nieuwer is nodig om de app zelf te bouwen.

```bash
./Scripts/build-app.sh
open Swift3270.app
```

## Verbinden

1. Open Swift3270.
2. Maak een sessie aan.
3. Vul hostnaam en poort in.
4. Stel indien nodig LU, TLS en codepage in.
5. Klik op **Connect**.

Gebruik certificaatuitzonderingen alleen wanneer dit binnen jouw omgeving nodig is.

## Updates

Bij het opstarten controleert Swift3270 of een nieuwe GitHub Release beschikbaar is. De app toont eerst de release notes en vraagt altijd toestemming voordat een update wordt geïnstalleerd.

Updates worden gecontroleerd met een SHA-256-checksum en validatie van de app-identiteit en versie.

## Privacy

Swift3270 werkt lokaal en maakt rechtstreeks via `b3270` verbinding met de host.

- Geen telemetry
- Geen schermlogging
- Geen permanente opslag van terminalinhoud
- Geen externe tussenserver

Opgeslagen profielen bevatten alleen verbindingsinstellingen. Tijdelijke schermgeschiedenis blijft uitsluitend in het geheugen.

## Problemen

Werkt `b3270` niet? Controleer eerst:

```bash
brew install x3270
```

Een eigen pad kan worden ingesteld met:

```bash
SWIFT3270_B3270_PATH=/pad/naar/b3270 open Swift3270.app
```

## Licentie

Swift3270 gebruikt de BSD 3-Clause License. x3270/b3270 is een afzonderlijk project met een BSD-achtige licentie.
