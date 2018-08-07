﻿<#

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
Fikse AzureADPreview på maskinen
.\InviterEksterneAAD.ps1 -fiksaadpreview

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
	# SkipTest lar være å teste om AADPreview er installert. Angi dersom testen skaper problemer.
	[switch]$skiptest,

	# KildeCSV angir CSV-filen data skal leses fra. Syntaks er E-postadresse;Visningsnavn med semi-kolon;Gruppe-ObjektID.
	[Parameter(Position=0,Mandatory=$True,ValueFromPipeLine=$True,HelpMessage="Bane til CSV-filen.",ParameterSetName='baner')]
	[string]$kildecsv,

	# (Valgfri) Sti angir URL den inviterte blir sendt til når de godtar invitasjonen.
	# Om denne ikke er angitt sendes de til $standardsti (endres i skriptet). 
	# Om denne er angitt vil e-posten alltid sende vedkommende til spesifik adresse.
	[Parameter(Position=1,Mandatory=$False,ValueFromPipelineByPropertyName,ParameterSetName='baner')]
	[string]$sti,

	# (Valgfri) Ikkekoblefra angir at vi ikke kobler fra skyen før/etter skriptet har kjørt.
	[Parameter(Position=2,Mandatory=$False,ValueFromPipelineByPropertyName,ParameterSetName='baner')]
	[switch]$ikkekoblefra,

	# FiksAAD angir at man vil installere/oppgradere AADPreview. 
	# OBS! Krever at skriptet kjøres elevert. Kan ikke kombineres med kildecsv eller site.
	[Parameter(ParameterSetName='pctest',Mandatory=$true)]
	[switch]$fiksaadpreview
)

function systemkrav {
	## Tester PC-en og ser etter at rett utgave av AzureAD-modulen er installert. 
	# Returnerer errorcode 3 dersom AADPreview mangler, eller 0 dersom alt er vel. 
	
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

function kobletilskyen {
	if($ikkekoblefra){return} else{
	$adminbruker = Get-Credential -Message "Angi bruker med admin-rolle i Office 365"
	# Koble til AAD
	$oktaad = Connect-AzureAD -Credential $adminbruker
	# Koble til EO
	$okteo = New-PSSession https://ps.outlook.com/PowerShell -AllowRedirection -Authentication Basic -Credential $adminbruker -ConfigurationName Microsoft.Exchange
	Import-PSSession $okteo -Prefix eo
	Write-Debug "Koblet til AAD og EO"
	}
}

function koblefraskyen {
	if ($okteo -ne $null){Remove-PSSession $okteo}
	Disconnect-AzureAD
	Write-Debug "Koblet fra EO og AAD"
}

Write-Debug "Tester verdien av angitte parametere"
if($fiksaadpreview){fiksaad;exit} # Vi installerer AADPreview for deg.
if(!$skiptest){systemkrav} # Med mindre skiptest er angitt, kjører vi en kjapp systemtest
if(!$kildecsv -eq $null){
	if(!(Test-Path $kildecsv)){
		Write-Error "Systemtest: Finner ikke filen $kildecsv"
		exit 2
		}
}

# Definerer variablene globalt og sørg for at alt er frakoblet, så kobler vi til
if ($ikkekoblefra -ne $true) {
	$adminbruker=$null;$oktaad=$null;$okteo=$null;
	koblefraskyen;
	kobletilskyen
	Write-Debug "Koblet til og fra"}
#############################################################################################
##
## Definer disse verdiene for din organisasjon:
# hvor ekstern blir sendt når de godtar invitasjonen dersom ikke annen adresse er angitt (-Site "http://....")
$standardsti = "https://www.office.com" 

# ønsket meldingstekst i invitasjonen fra AzureAD
$meldingstekst = "Velkommen som foresatt til vår skole. Du vil motta ytterligere informasjon fra oss." # Denne egendefinerte meldingsteksten vises i invitasjonen de mottar

##############################################################################################
## Skriptets hovedlogikk løper herfra
##

# leser inn angitt CSV-fil, antar ";" som skilletegn mellom kolonner og en header-rad med epost;visningsnavn;gruppeid
$invitasjoner = Import-Csv $kildecsv -Delimiter ";" 
foreach ($rad in $invitasjoner) {
		# Test at alle verdier er tilstede for en gitt rad, avbryt operasjonen om raden er tom
		if(($gjest.epost -or $gjest.visningsnavn -or $gjest.gruppeid) -eq $null)	{
			Write-Error "Manglende verdier for $gjest.epost"	
			break # Bryter for brukeren som mangler verdier
		}
	}

# Bygg invitasjonsmeldingen
$melding = New-Object Microsoft.Open.MSGraph.Model.InvitedUserMessageInfo
$melding.CustomizedMessageBody = $meldingstekst

# avgjøre om sti er angitt og gå til standardverdi om ikke:
if($sti -ne $null) {
	$sti=$standardsti
	Write-Debug "Går for standardverdi da -Sti ikke er angitt til verdi"
}

# Behandle hver rad
ForEach ($gjest in $invitasjoner) {
		# Klargjør meldingstekst for fremdriftsindikator
		[string]$aktivitetsmelding = "Inviterer " + ($gjest.epost).ToString() 
		
		# Inviter person og lagre utfallet
		Write-Progress -Activity $aktivitetsmelding -Status "Sender gjesteinvitasjon fra AAD"
		$resultat = New-AzureADMSInvitation -InvitedUserEmailAddress $gjest.epost -InvitedUserDisplayName $gjest.visningsnavn -InviteRedirectUrl $sti -InvitedUserMessageInfo $melding -SendInvitationMessage $True
		Write-Debug "Invitasjon sendt for $gjest"
		
		# Fra utfallet av importen har vi adressen vedkommende ble invitert til og bruker-id i AzureAD
		$inviteretil = $resultat.InviteRedeemUrl
		$brukerid = $resultat.InvitedUser.Id

		# Vi legger den inviterte til i ønsket Office 365-Gruppe
		Write-Progress -Activity $aktivitetsmelding -Status "Legger bruker inn i gruppe"
		Add-AzureADGroupMember -ObjectId $gjest.gruppeid -RefObjectId $brukerid
		Write-Debug "Lagt " $gjest.epost " i gruppe " $gjest.gruppeid
	}
Write-Progress -Activity "Avslutter" -Completed


#############################################################################################
## Skriptet er ferdig og vi avslutter
#
return

## Kilde-henvisninger
# https://social.technet.microsoft.com/wiki/contents/articles/15994.powershell-advanced-function-parameter-attributes.aspx
# Sende flere invitasjoner: https://docs.microsoft.com/en-us/powershell/module/azuread/new-azureadmsinvitation?view=azureadps-2.0
#	Forrige: https://www.adamfowlerit.com/2017/03/azure-ad-b2b-powershell-invites/
# Eksempel med egendefinert melding https://sileotech.com/sharepoint-online-azure-ad-b2b-custom-email-invites-users-using-powershell/
# Sende egendefinert e-post: https://gallery.technet.microsoft.com/scriptcenter/Send-MailMessage-3a920a6d

## av tomrune@knowledgegroup.no 2018-07-05
#
