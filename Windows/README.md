# Swift3270 voor Windows

Deze handleiding begint bij een lege Windows 10- of Windows 11-computer. Je kunt Swift3270 op twee manieren gebruiken:

- **Alleen gebruiken:** download een kant-en-klare release. Swift en Visual Studio zijn dan niet nodig.
- **Zelf bouwen:** installeer Swift 6.2 of nieuwer, de Microsoft C++-hulpmiddelen en Git.

In beide gevallen heeft Swift3270 `ws3270.exe` nodig om verbinding te maken met een IBM-mainframe.

## Route A — een kant-en-klare release gebruiken

### 1. Download Swift3270

Ga naar [GitHub Releases](https://github.com/prosir/Swift3270/releases) en download het Windows ZIP-bestand van de nieuwste release.

Pak het ZIP-bestand uit, bijvoorbeeld naar:

```text
C:\Apps\Swift3270
```

Als bij de release een bestand met SHA-256-controlesommen staat, kun je de download in PowerShell controleren:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\Swift3270-Windows.zip" -Algorithm SHA256
```

Vergelijk de getoonde waarde met de SHA-256-waarde op de releasepagina.

### 2. Installeer ws3270

`ws3270.exe` is onderdeel van de Windows-versie van de x3270-suite. Open de [officiële x3270-downloadmap](https://x3270.bgp.nu/download/04.05/) en download de nieuwste `wc3270-...-setup.exe`. De versie die bij het schrijven van deze handleiding beschikbaar is, is [wc3270 4.5ga6](https://x3270.bgp.nu/download/04.05/wc3270-4.5ga6-setup.exe).

Voer de installer uit en open daarna een nieuwe PowerShell. Controleer of Windows `ws3270.exe` kan vinden:

```powershell
Get-Command ws3270.exe -ErrorAction SilentlyContinue
```

Krijg je geen resultaat, zoek het programma dan in de gebruikelijke installatiemappen:

```powershell
Get-ChildItem "C:\Program Files", "C:\Program Files (x86)" -Filter ws3270.exe -Recurse -ErrorAction SilentlyContinue
```

Bewaar het volledige gevonden pad. Je kunt dit pad later in Swift3270 invullen.

### 3. Start Swift3270

Open de uitgepakte map en dubbelklik op `Swift3270.exe`.

Windows SmartScreen kan bij een niet-ondertekende testrelease een waarschuwing tonen. Controleer eerst of je het bestand werkelijk van de officiële GitHub-release hebt gedownload en controleer waar mogelijk de SHA-256-som.

Ga daarna verder bij [Swift3270 instellen](#swift3270-instellen).

## Route B — Swift3270 zelf bouwen

Voor het bouwen heb je nodig:

1. Windows 10 of Windows 11, 64-bit;
2. Visual Studio 2022 met de C++ build tools en Windows SDK;
3. Swift 6.2 of nieuwer;
4. Git;
5. `ws3270.exe` voor de uiteindelijke 3270-verbinding.

Open PowerShell als administrator voor de installatiestappen hieronder.

### 1. Installeer de Microsoft C++ build tools

De officiële Swift-handleiding voor Windows adviseert Visual Studio 2022 met de Windows SDK en de x64/x86- en ARM64-C++-tools. Installeer die onderdelen met:

```powershell
winget install --id Microsoft.VisualStudio.2022.Community --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64" --source winget
```

Dit is een grote installatie en kan enige tijd duren.

Gebruik je liever de grafische installer? Download dan [Visual Studio Community](https://visualstudio.microsoft.com/vs/community/), kies **Desktop development with C++** en zorg dat een recente Windows 10/11 SDK is aangevinkt.

Herstart Windows wanneer de installer daarom vraagt.

### 2. Installeer Swift 6.2 of nieuwer

Swift3270 vereist minimaal Swift 6.2. De eenvoudigste keuze is de huidige stabiele Swift-toolchain via WinGet:

```powershell
winget install --id Swift.Toolchain --exact --source winget
```

Wil je specifiek de 6.2-serie gebruiken, download dan de officiële [Swift 6.2.4-installer voor Windows x64](https://download.swift.org/swift-6.2.4-release/windows10/swift-6.2.4-RELEASE/swift-6.2.4-RELEASE-windows10.exe). Voor ARM64 en andere versies staat de volledige lijst op [Swift installeren op Windows](https://www.swift.org/install/windows/).

Sluit na de installatie alle PowerShell-vensters en open een nieuw venster. Controleer vervolgens:

```powershell
swift --version
```

De uitvoer moet versie `6.2` of hoger tonen. Bijvoorbeeld:

```text
Swift version 6.2.4 (...)
Target: x86_64-unknown-windows-msvc
```

Een nieuwere stabiele Swift-versie is ook geschikt.

### 3. Installeer Git

Installeer Git via WinGet:

```powershell
winget install --id Git.Git --exact --source winget
```

Of gebruik de [officiële Git for Windows-download](https://git-scm.com/download/win).

Open daarna opnieuw PowerShell en controleer:

```powershell
git --version
```

### 4. Installeer ws3270

Open de [officiële x3270-downloadmap](https://x3270.bgp.nu/download/04.05/), download de nieuwste `wc3270-...-setup.exe` en voer de installer uit. De versie die bij het schrijven van deze handleiding beschikbaar is, is [wc3270 4.5ga6](https://x3270.bgp.nu/download/04.05/wc3270-4.5ga6-setup.exe).

Controleer daarna:

```powershell
Get-Command ws3270.exe -ErrorAction SilentlyContinue
```

Als er niets wordt gevonden, zoek je het bestand zo:

```powershell
Get-ChildItem "C:\Program Files", "C:\Program Files (x86)" -Filter ws3270.exe -Recurse -ErrorAction SilentlyContinue
```

Noteer het volledige pad; dat kun je in Swift3270 bij **ws3270-pad** invullen.

### 5. Download de broncode

Maak eerst een projectmap:

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\source" -Force
cd "$env:USERPROFILE\source"
```

Clone daarna de repository en open de Windows-package:

```powershell
git clone https://github.com/prosir/Swift3270.git
cd Swift3270\Windows
```

Je kunt de broncode ook als ZIP downloaden via GitHub. Pak het archief uit en open PowerShell in de map `Swift3270\Windows`.

### 6. Download de Swift-pakketten en voer de tests uit

Voer vanuit de map `Swift3270\Windows` uit:

```powershell
swift package resolve
$env:SWIFT3270_CORE_ONLY = "1"
swift test --jobs 2
Remove-Item Env:\SWIFT3270_CORE_ONLY
```

De eerste keer worden de Swift-afhankelijkheden gedownload. Dat kan enkele minuten duren. De Core-only instelling voorkomt dat de grote WinUI/CWinRT-library tijdens de tests al wordt gebouwd.

### 7. Bouw de Windows-app

Maak daarna de volledige release-build:

```powershell
swift build -c release --product Swift3270Windows --jobs 2
```

De WinUI-afhankelijkheid bevat honderden gegenereerde bestanden. De eerste volledige build kan daardoor duidelijk langer duren dan de tests. Bij volgende builds helpt de SwiftPM-cache.

Zoek het gebouwde EXE-bestand:

```powershell
Get-ChildItem .build -Recurse -Filter Swift3270Windows.exe |
    Where-Object { $_.FullName -match '\\release\\' }
```

Start de eerste gevonden release-build:

```powershell
$app = Get-ChildItem .build -Recurse -Filter Swift3270Windows.exe |
    Where-Object { $_.FullName -match '\\release\\' } |
    Select-Object -First 1

& $app.FullName
```

## Swift3270 instellen

Vul in het verbindingsvenster minimaal de volgende gegevens in:

- **Host:** DNS-naam of IP-adres van het mainframe;
- **Port:** de TN3270-poort van de omgeving;
- **LU:** optioneel, alleen wanneer de omgeving een specifieke logical unit vereist;
- **TLS:** inschakelen wanneer de host een beveiligde TN3270-verbinding gebruikt;
- **Model:** meestal model 2, tenzij de beheerder iets anders voorschrijft;
- **ws3270-pad:** alleen nodig wanneer `ws3270.exe` niet via `PATH` wordt gevonden.

Klik daarna op **Verbinden**.

Vraag hostnaam, poort, TLS-instelling en eventueel LU op bij de mainframebeheerder. Gebruik geen willekeurige productiegegevens om de verbinding te testen.

## Automatisch inloggen

Swift3270 kan één volledige CICS-login automatisch afhandelen:

1. Zet **Automatisch invullen + Enter** aan.
2. Vul bij **Toepassing** bijvoorbeeld `TSOT` of `COF1R1` in.
3. Vul de gebruikers-ID en het wachtwoord of de password phrase in.
4. Klik eenmaal op **Verbinden**.

De invoer wordt aan de hand van de schermtekst herkend en in de juiste velden gezet:

- `Kies uw toepassing ==>` → toepassing;
- `SESSION ENTER USERID` → gebruikers-ID;
- `ENTER PASSWORD` → wachtwoord of password phrase;
- het CICS-scherm met `User-ID ==>` en `Password/phrase ==>` → gebruikers-ID en wachtwoord.

Elke stap wordt met een korte vertraging ingevuld en met Enter bevestigd. Het wachtwoord blijft alleen in het werkgeheugen staan en wordt niet in de instellingen opgeslagen.

## Bediening

- Klik in een invoerveld en typ direct.
- Druk op `Enter` om de invoer te verzenden.
- Gebruik de knoppen `PF1` tot en met `PF24` voor functietoetsen.
- Gebruik `Reset` wanneer de terminal een operatorfout meldt of het toetsenbord geblokkeerd is.
- Met **Opnieuw verbinden** wordt dezelfde sessie opnieuw opgebouwd.

## COBOL-compilerfouten

De Windows-app herkent veel voorkomende COBOL-compileruitvoer, waaronder IBM Enterprise COBOL-meldingen met codes zoals `IGY...` en regels met `ERROR`, `WARNING`, `SEVERE` of `FATAL`.

Bij een gedetecteerde fout toont Swift3270 de unieke foutcodes onder het terminalscherm. Klik op een code om de bijbehorende IBM-documentatie te openen.

## Problemen oplossen

### `swift` wordt niet herkend

Sluit PowerShell volledig en open het opnieuw. Werkt dat niet, herstart Windows en voer `swift --version` nogmaals uit. Controleer anders via **Geïnstalleerde apps** of de Swift Toolchain is geïnstalleerd.

### De compiler kan `link.exe`, MSVC of de Windows SDK niet vinden

Open **Visual Studio Installer**, kies **Modify** en installeer **Desktop development with C++** plus een recente Windows 10/11 SDK. Open daarna een nieuw PowerShell-venster.

### De build blijft staan op `Archiving libCWinRT.a`

`libCWinRT.a` is groot en de eerste archivering kan enkele minuten duren. Bouw met maximaal twee gelijktijdige taken:

```powershell
swift build -c release --product Swift3270Windows --jobs 2
```

Controleer in Taakbeheer of `swift.exe`, `clang.exe` of de librarian nog CPU of schijf gebruikt. Is er twintig minuten helemaal geen activiteit, stop de build, verwijder alleen de lokale buildcache en probeer opnieuw:

```powershell
swift package clean
swift build -c release --product Swift3270Windows --jobs 2
```

GitHub Actions bouwt de Core-tests apart, stelt de Visual Studio-omgeving expliciet in en begrenst de WinUI-build tot veertig minuten.

### Swift Package Manager kan pakketten niet downloaden

Controleer internettoegang, proxy en firewall. Probeer daarna:

```powershell
swift package reset
swift package resolve
```

### `ws3270.exe` wordt niet gevonden

Zoek het bestand met het PowerShell-commando uit deze handleiding en vul het volledige pad in bij **ws3270-pad**. Controleer ook of antivirussoftware het bestand niet in quarantaine heeft geplaatst.

### Verbinden lukt niet

Controleer hostnaam, poort, TLS, LU en VPN. Een bereikbare webpagina betekent niet automatisch dat de TN3270-poort bereikbaar is. Vraag de juiste waarden aan de mainframebeheerder.

### Het terminaltoetsenbord blijft geblokkeerd

Wacht eerst tot de host klaar is met verwerken. Klik daarna op **Reset**. Verbreek en herstel de verbinding wanneer het probleem blijft bestaan.

## Een bestaande broncode-installatie bijwerken

```powershell
cd "$env:USERPROFILE\source\Swift3270"
git pull
cd Windows
swift package resolve
$env:SWIFT3270_CORE_ONLY = "1"
swift test --jobs 2
Remove-Item Env:\SWIFT3270_CORE_ONLY
swift build -c release --product Swift3270Windows --jobs 2
```

## Wat de Windows-versie ondersteunt

- native Windows-venster via WinUI;
- TN3270-verbinding via `ws3270`;
- model 2 tot en met 5 en aangepaste terminalafmetingen;
- TLS en LU-configuratie;
- 3270-invoervelden, cursorplaatsing en kleurweergave;
- Enter, Clear, Reset, Tab, Backtab, pijltjes, Insert, PA1-PA3 en PF1-PF24;
- kopiëren en plakken;
- opnieuw verbinden en tijdelijke schermgeschiedenis;
- automatische TSO- en CICS-login;
- COBOL-compilerfoutdetectie;
- lokale opslag van niet-gevoelige voorkeuren.

## Projectindeling

- `Sources/Swift3270WindowsCore`: protocol, parser, sessie, automatische login en COBOL-detectie;
- `Sources/Swift3270Windows`: WinUI-interface en Windows-appmodel;
- `Tests/Swift3270WindowsCoreTests`: tests die zonder Windows-interface kunnen draaien.

De GitHub Actions-workflow bouwt en test de Windows-versie automatisch en maakt bij een release een Windows-archief met SHA-256-controlesommen.
