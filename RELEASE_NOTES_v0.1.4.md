# Swift3270 v0.1.4

Deze release maakt Swift3270 stabieler, sneller en prettiger voor dagelijks mainframe-development.

## Nieuw

- Ingebouwd pluginsysteem met opgeslagen voorkeuren.
- **Host Search** via `Cmd+F`, inclusief Vorige en Volgende.
- **Trackpad Navigation**: scrollen met twee vingers, horizontaal en verticaal.
- **Screen History**: tijdelijk eerdere schermen bekijken zonder logging.
- **Smart Selection**: slepen, dubbelklikken en betere tekstselectie.
- **Terminal Clipboard** met `Cmd+C` en `Cmd+V`.
- **Developer Split**: twee actieve sessies naast elkaar.
- **Personalize** met een echte macOS-kleurkiezer.
- Automatisch zwarte of witte tekst afhankelijk van de gekozen achtergrondkleur.

## Terminal en SFDII

- Betere ondersteuning voor Model 2, 3, 4, 5 en oversize `80×62`.
- Verbeterde weergave van SFDII-schermen met Fields en Format.
- Minder verdwijnende regels, flikkering en trage schermupdates.
- Actieve sessies worden niet onverwacht afgesloten bij modelwijzigingen.
- Duidelijkere foutmeldingen zonder voortdurende reconnectpop-ups.
- Nieuwe handmatige Disconnect- en Reconnect-bediening.

## Interface

- Compactere bovenbalk met consistente knopmaten.
- Opgeschoonde statusbalk met live **Regel en Kolom**.
- Compacte weergave van Insert, Lock, model en schermafmetingen.
- Normale statusmeldingen verdwijnen automatisch.
- Splitpanelen tonen hun eigen sessie- en cursorinformatie.
- Persoonlijke kleuren worden toegepast op geselecteerde tabs, badges en actieve knoppen.
- Terminalkleuren blijven afzonderlijk instelbaar via **Options → Colors**.

## Opstarten en updates

- Nieuw compact opstartscherm met voortgangsbalk.
- Automatische controle op GitHub Releases.
- Release notes worden voor het starten getoond.
- Updates kunnen automatisch worden gedownload, gecontroleerd en geïnstalleerd.
- Validatie van SHA-256, app-identiteit, executable en versienummer.
- Verbeterde GitHub Actions-verpakking met app-zip en checksum.

## Privacy

- Geen schermlogging.
- Geen permanente opslag van terminalinhoud.
- Geen telemetry of externe tussenserver.
- Schermgeschiedenis blijft uitsluitend tijdelijk in het geheugen.
