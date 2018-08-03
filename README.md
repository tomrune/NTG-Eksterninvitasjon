# NTG-Eksterninvitasjon
Skript for invitasjon av foreldre og foresatte til Office 365 Edu.

Krav:
- installere AzureADPreview
  Skriptet kan gjøre dette for deg ved å åpne Powershell med admin-tilgang og så:
  Skriv: 
    - Unblock-File C:\users\mittbrukernavn\downloads\InviterEksterneAAD.ps1
    - Set-ExecutionPolicy RemoteSigned
    - .\InviterEksterneAAD.ps1 -fiksaadpreview
  
- I skriptet, modifiser meldingshilsen om ønskelig. Denne vises i e-posten foreldrene får.
- Modifiser eller opprett en CSV-fil. Påse at først rad inneholder epost;visningsnavn
- For hver forelder, angi e-postadresse;Ønsket navn de skal vises med i katalogen

###########
Bruk:
- Åpne Powershell-vindu (krever ikke admin-tilgang)
- For å logge på Office 365 for skriptet, skriv: Connect-AzureAD
  - logg på med en bruker som har admin-rolle Brukeradministrator eller høyere i Office 365, eller som har Guest Invite-tillatelse i AzureAD.

- Kjør skriptet: 
  - .\InviterEksterneAAD.ps1 -kildecsv c:\csvfil.csv
  
