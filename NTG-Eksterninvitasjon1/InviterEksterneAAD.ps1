<#

.SYNOPSIS
Dette skriptet lar deg bulkinvitere eksterne personer fra en CSV-fil

.DESCRIPTION
Bruk dette skriptet for å invitere en liste med foresatte til AzureAD fra en semikolon-separert CSV-fil.
Se Get-Help InviterEksterneAAD.ps1 -Parameter kildecsv for syntaks for en gitt parameter.
Se Get-Help InviterEksterneAAD.ps1 -Full for fler detaljer om skript og CSV-filen.

.EXAMPLE
Inviter alle foresatte til AAD generelt. De må bekrefte invitasjonen innen 90 dager. Deretter kan de deles fritt med i alle områder.
.\InviterEksterneAAD.ps1 -KildeCSV .\Foresatte2018-2019.csv

.EXAMPLE
Inviter alle foresatte til 
.\InviterEksterneAAD.ps1

.NOTES
Syntaks for CSV-filen er "E-post;Visningsnavn" med semikolon. Dette tillater bruk av komma i visningsnavn.
Du kan transformere komma til semi-kolon for en CSV-fil ved å bruke f.eks. 
	$elevliste = Import-CSV .\elevene1.csv -Delimiter ","
	$elevliste = Export-CSV .\elevene2.csv -Delimiter ";"

Returkoder er 0 - alt vel, 2 - KildeCSV-fil mangler, 3 - FiksAADPreview er utført.
Skriptet er skrevet av tomrune@knowledgegroup.no 

.LINK
http://www.knowledgegroup.no 

#>


## Evaluer parametere angitt ved oppstart
[CmdletBinding(DefaultParameterSetName='baner')]
Param(
	# Skiptest lar være å teste om AADPreview er installert. Angi dersom testen skaper problemer.
	[switch]$skiptest,

	# KildeCSV angir CSV-filen data skal leses fra. Syntaks er E-postadresse;Visningsnavn med semi-kolon.
	[Parameter(Position=0,Mandatory=$True,ValueFromPipeLine=$True,HelpMessage="Bane til CSV-filen.",ParameterSetName='baner')]
	[string]$kildecsv,

	# (Valgfri) Site angir SharePoint-område de skal inviteres til.
	# Om denne ikke er angitt inviteres de generelt til skolen. 
	# Om denne er angitt inviteres de spesifikt til angitt område.
	[Parameter(Position=1,Mandatory=$False,ValueFromPipelineByPropertyName,ParameterSetName='baner')]
	[string]$site,

	# FiksAAD angir at man vil installere/oppgradere AADPreview. 
	# OBS! Krever at skriptet kjøres elevert.
	[Parameter(ParameterSetName='pctest',Mandatory=$true)]
	[switch]$fiksaadpreview
)

function systemkrav {
	## Tester PC-en og ser etter at rett utgave av AzureAD-modulen er installert. 
	# Returnerer errorcode 3 dersom AADPreview mangler, eller 0 dersom alt er vel. 
	
	# Avgjør om rett PowerShell-utgave
	# kommer i v2

	# Avgjøre om Azure AD Preview er installert
	if(Get-Module -ListAvailable -Name AzureADPreview) {
		if($fiksaadpreview) { #Vi viser bare dette dersom fiks-parameter er angitt
			Write-Host "Systemtest: AzureADPreview er tilgjengelig."
			Write-Host "Din PowerShell-versjon er " ($PSVersionTable.PSversion.Major)
			} #endif 
		} else {
			if(Get-Module -ListAvailable -Name AzureAD) {
				Write-Warning "Systemtest: AzureAD-modul er installert. Vi må ha AzureADPreview!"
			}
			else{
				Write-Error "Systemtest: Ingen moduler for AzureAD er installert!"
			} #endif
		Write-Host "Vi behøver AzureADPreview. Bruk parameter -fiksaadpreview for å installere."
		exit 3;
	} #endif
}

function fiksaad {
	## Installerer/oppgraderer AADPreview, avinstallerer AAD om nødvendig. 
	
	# Er vi lokaladmin?
	if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		Write-Error "Systemtest: Skriptet må kjøres som lokaladmin for å installere AzureAD!"
		exit 3;
	} else {
		if(Get-Module -ListAvailable -Name AzureADPreview) { # Avinstaller evt AADPreview for å installere siste versjon
				Uninstall-Module AzureADPreview -Force
		} else {
			if(Get-Module -ListAvailable -Name AzureAD) { # Avinstaller AAD
				Uninstall-Module AzureAD -Force
			} #endif
		} #endif
		# Installer AADPreview
		Write-Host "Installerer siste utgave av AADPreview. Du kan bli bedt om å midlertidig stole på psgallery."
		Install-Module AzureADPreview -Force
		systemkrav # Kjapp test for å se at installasjonen gikk i orden.
		Write-Host "Du kan nå kjøre skriptet som vanlig bruker. Lokaladmin er ikke lenger nødvendig."
		exit;
	}
}

if($fiksaadpreview){fiksaad;exit} # Vi installerer AADPreview for deg.
if(!$skiptest){systemkrav} # Med mindre skiptest er angitt, kjører vi en kjapp systemtest
if(!$kildecsv -eq ""){
	if(!(Test-Path $kildecsv)){
		Write-Error "Systemtest: Finner ikke filen $kildecsv"
		exit 2
		}
}

#############################################################################################
##
## Skriptets hovedlogikk starter her
#

$gjester = Import-Csv $kildecsv -Delimiter ";" 

$gjester = % {
	New-AzureADMSInvitation -InvitedUserEmailAddress $_.epost -InvitedUserDisplayName $_.visningsnavn -InviteRedirectUrl "https://myapps.microsoft.com" -SendInvitationMessage $True
	}


#############################################################################################
## Skriptet er ferdig og vi avslutter
#
return

## Kilde-henvisninger
# https://social.technet.microsoft.com/wiki/contents/articles/15994.powershell-advanced-function-parameter-attributes.aspx
# 
## TODO
# - Test Powershell-versjon
# - Generer eksempel-CSV

## av tomrune@knowledgegroup.no 2018-07-05
#
