<#

.SYNOPSIS
Dette skriptet legger foresatte inn i Exchange Online Mail Enabled Security Groups fra en CSV-fil

.DESCRIPTION
Bruk dette skriptet for å invitere en liste med foresatte til AzureAD fra en semikolon-separert CSV-fil.
Se Get-Help EOGruppeTilordning.ps1 -Parameter kildecsv for syntaks for en gitt parameter.
Se Get-Help EOGruppeTilordning.ps1 -Full for fler detaljer om skript og CSV-fil.

.EXAMPLE
Legg alle foresatte inn i respektive Exchange Online-grupper.
.\EOGruppeTilordning.ps1 -KildeCSV .\Foresatte2018-2019.csv

.NOTES
Syntaks for CSV-filen er "epost;visningsnavn;aadgruppeid;eogruppenavn;url" med semikolon. Dette tillater bruk av komma i visningsnavn.
Du kan transformere komma til semi-kolon for en CSV-fil ved å bruke f.eks. 
	$elevliste = Import-CSV .\elevene1.csv -Delimiter ","
	$elevliste = Export-CSV .\elevene2.csv -Delimiter ";"

Returkoder er 0 - alt vel, 2 - KildeCSV-fil mangler
Skriptet er skrevet av tomrune@knowledgegroup.no 

.LINK
http://www.knowledgegroup.no 

#> # Hjelpeblokk

## Evaluer parametere angitt ved oppstart
[CmdletBinding()]
Param(
	# KildeCSV angir CSV-filen data skal leses fra. Syntaks er E-postadresse;Visningsnavn med semi-kolon;AADGruppe-ObjektID;EOGruppeNavn;URL.
	[Parameter(Position=0,Mandatory=$True,ValueFromPipeLine=$True,HelpMessage="Bane til CSV-filen.")]
	[string]$kildecsv
) # Defininsjon og krav for parametere til skriptet

function kobletileo {
	try { $proveeo = Get-TransportConfig } 
	catch [Management.Automation.CommandNotFoundException] { 
		Write-Host "Vi er ikke koblet til Exchange Online. Kobler til..."
		$eoadmin = Get-Credential -Message "Angi bruker med administrasjonsrolle"
		$eookt = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $eoadmin -Authentication Basic -AllowRedirection
		Import-PSSession $eookt -DisableNameChecking
	}
} # Test om kobling til EO er aktiv og koble til om ikke

if(!$kildecsv -eq $null){
	# Sjekk at filen finnes
	if(!(Test-Path $kildecsv)){
		Write-Error "Systemtest: Finner ikke filen $kildecsv"
		exit 2
		}
} # Rask sjekk om filen finnes

##############################################################################################
## Skriptets hovedlogikk løper herfra
##

# leser inn angitt CSV-fil, antar ";" som skilletegn mellom kolonner og en header-rad med 
# epost;visningsnavn;gruppeid;url
$invitasjoner = Import-Csv $kildecsv -Delimiter ";" 
foreach ($rad in $invitasjoner) {
		# Test at kritiske verdier er tilstede for en gitt rad, avbryt operasjonen om verdien er tom
		if(($gjest.epost -or $gjest.visningsnavn -or $gjest.eogruppenavn -or $gjest.URL) -eq $null)	{
			Write-Error "Mangler verdier for $gjest.epost. Bruk Get-Help på skriptet for å se syntaks for CSV."	
			break # Bryter for brukeren som mangler verdier
		}
	}

# Sjekk om vi er tilkoblet EO
kobletileo

# Behandle hver rad
ForEach ($gjest in $invitasjoner) {
		# Klargjør meldingstekst for fremdriftsindikator
		[string]$aktivitetsmelding = "Legger til " + ($gjest.visningsnavn).ToString() 
		
		# Inviter person og lagre utfallet
		Write-Progress -Activity $aktivitetsmelding -Status "Legger foresatt i Gruppe"
		$resultat = Add-DistributionGroupMember -Identity $gjest.eogruppenavn -Member $gjest.epost
		Write-Debug "La til $gjest"		
	}
Write-Progress -Activity "Avslutter" -Completed


#############################################################################################
## Skriptet er ferdig og vi avslutter
#
return
