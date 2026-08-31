# Swift3270 – Insert & Selection Update

Deze update verbetert het werken met COBOL-broncode in de terminal.

## Insertmodus

- `⌘⇧I` zet de Insertmodus betrouwbaar aan.
- Insertmodus gebruikt nu een dunne verticale cursor.
- Overschrijfmodus blijft herkenbaar aan de blokcursor.
- Eindspaties worden beter als beschikbare invoerruimte behandeld.
- Een operator error ontgrendelt de terminal automatisch.
- Bij een vol of beveiligd veld verschijnt een duidelijke melding met regel en kolom.
- De melding verdwijnt automatisch na vijf seconden.

## Selecteren en knippen

- Selecteren met `Shift + ← ↑ ↓ →`.
- Selectie uitbreiden per teken, kolom of regel.
- Verbeterde selectie met muis en trackpad.
- `⌘C` kopieert de geselecteerde terminaltekst.
- `⌘X` maakt geselecteerde posities leeg zonder de overige COBOL-code te verschuiven.
- Regelnummering en terminaltekst worden exact gekopieerd wanneer ze binnen de selectie vallen.

## Nieuwe plugin: COBOL Vakselectie

- Trek een strak rechthoekig selectievak over COBOL-code.
- Alleen de regels en kolommen binnen het vak worden geselecteerd.
- Voorkomt dat volledige tussenliggende regels onbedoeld meekomen.
- Schakel Vakselectie aan of uit met `⌘⇧B`.
- Uitgeschakeld gebruikt Swift3270 de normale doorlopende tekstselectie.
- De ingestelde pluginvoorkeur wordt automatisch opgeslagen.
