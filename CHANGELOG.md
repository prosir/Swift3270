# Changelog

## v0.1.2

Deze versie maakt Swift3270 vooral praktischer voor dagelijks gebruik en eerlijker rondom releases.

### Nieuw

- Update-melding bij opstart als er een nieuwere GitHub release is.
- Changelog van de nieuwste GitHub release wordt in de app getoond.
- Knop om direct de GitHub release te openen.
- Copy/paste ondersteuning in de terminal.
- Tekstselectie met muis/trackpad.
- 4K/Retina auto-fit scaling voor de terminal.
- Extra fontgroottes voor grote schermen.

### Verbeterd

- Terminal scaling is sneller gemaakt na de 4K-aanpassing.
- Klikken in de terminal is stabieler gemaakt na de selectie-aanpassingen.
- Keypad opent niet meer automatisch en schuift rustiger in.
- Build-script ondersteunt nu versie en buildnummer via:

```bash
SWIFT3270_VERSION=0.1.2 SWIFT3270_BUILD=3 ./Scripts/build-app.sh
```

### Release flow

- Automatische `.app` releases via GitHub Actions zijn uitgezet.
- GitHub Actions doet nu alleen een Swift release build check.
- README legt nu uit hoe je lokaal bouwt en `Swift3270.app` naar Applications sleept.
- README legt uit dat de app unsigned is zolang er geen Apple Developer signing/notarization is.

### Veiligheid/privacy

- Update-check haalt alleen publieke GitHub release metadata op.
- Geen terminaldata, hostnames, sessies of scherminhoud worden verstuurd.
- Updates worden niet automatisch gedownload of geïnstalleerd.

### Bekend

- App icon generatie kan lokaal nog een `Invalid Iconset` waarschuwing geven. De build gaat dan gewoon door zonder custom icon.

