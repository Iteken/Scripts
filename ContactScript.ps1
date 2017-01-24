## Input / setup parameters 
param (
    [Parameter()] [string]$sourceDomain = "admin.tower",
    [Parameter()] [string]$sourceOU = "OU=OU staff accounts,DC=admin,DC=tower",
    [Parameter()] [string]$destDomain = "ncclondon.ac.uk",
    [Parameter()] [string]$destOU = "OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk",
## variables for caching credentials
    [string]$file = "o:\scripts\password.NCC",
    [string]$user = "mchristopher@ncclondon.ac.uk",
## Adding an optional parameter to cleanup old users from the Source OU
    [Parameter(Mandatory=$false)] [switch]$Cleanup,
    [Parameter(Mandatory=$false)] [switch]$Loud
    )

#  .\ContactScript.ps1 -sourceDomain admin.tower -sourceOU "OU=IT Services,OU=OU staff accounts,DC=admin,DC=tower" -destDomain "ncclondon.ac.uk" -destOU "OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk"

## Setup constants
$destExch = "NC-PL-Mail-1.ncclondon.ac.uk"
$DestDC = "NC-PL-DC-1.ncclondon.ac.uk"

if ($loud) {
## output all the good stuff
    Write-Output "Intitalizing Contact Creation Script...."
    write-output "----------------------------------------"
    Write-Output "Session variables:"
    write-output "Source Domain: $($sourcedomain)"
    write-output "Source OU: $($sourceou)"
    write-output "Destinaion Domain: $($destdomain)"
    write-output "Destination OU: $($destOU)"
    write-output "--------------"
    write-output "Destination Exchange: $($destexch)"
    write-output "Destination DC: $($destDC)"
    write-output "--------------"
    write-output "Password file: $($file)"
    write-output "User account: $($user)"
    write-output "--------------"
    write-output "Initializing ......"

}

###############
## Functions ##
###############
function Update-contactrecord ($Record) {
## include customisable atribute #1: Site
<# variables to set:
        Givenname
        Displayname
        SN
        Initials
        Department
        Description
        Telephonenumber (not done) (fixed)
        Ipphone (full phone number)
        --
        street address
        State
        st
        PostalCode
        Job Title
        Company
        Office
        #>
        $contact = get-adobject "CN=$($Record.name),$($destOU)" -server $destDomain
        try {
            if ($Record.givenname -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'givenname'=$Record.givenname} }
            if ($Record.displayname -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'displayname'=$Record.displayname} }
            if ($Record.sn -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'sn'=$Record.sn} }
            if ($Record.Initials -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'initials'=$Record.Initials} }
            if ($Record.Department -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'Department'=$Record.Department} }
            if ($Record.Description -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'Description'=$Record.Description} }
            if ($Record.TelephoneNumber -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'TelephoneNumber'=$Record.Telephonenumber} }
            if ($Record.IpPhone -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'IpPhone'=$Record.IpPhone } }
            if ($record.StreetAddress -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'StreetAddress'=$record.Streetaddress}}
            if ($record.St -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'ST'=$record.St}}
            if ($record.PostalCode -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'PostalCode'=$record.PostalCode}}
            if ($record.Title -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'Title'=$record.Title}}
            if ($record.Company -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'Company'=$record.Company}}
            ## special case for hackney's shoddy data
                elseif ($destdomain -eq "hackney.local") {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'Company'="Hackney"}}
            if ($record.physicalDeliveryOfficeName -ne $null) {set-adobject -server $destdomain -identity $contact -credential $creds -replace @{'physicalDeliveryOfficeName'=$record.physicalDeliveryOfficeName}}
            if ($record.ThumbnailPhoto -ne $null) {set-adobject  -server $destdomain -identity $contact -credential $creds -replace @{'ThumbnailPhoto'=$record.ThumbnailPhoto}}
            if ($loud) {write-output "OK: Updated Contact details for $($Record.name)."}
          }
        catch {write-output "Warning:  Error updating contact details. $($record.name) may have incomplete data"}
        $mailcontact = get-mailcontact "CN=$($Record.name),$($destOU)" -domaincontroller $DestDC
        if ($mailcontact.emailaddresspolicyenabled -eq $true) 
                {
                    set-mailcontact "CN=$($Record.name),$($destOU)" -domaincontroller $DestDC -emailaddresspolicyenabled $false
                }
	    $mailcontact.EmailAddresses | ?{$_ -like "*@NCCLondon*"} | %{
		        Set-Mailcontact  "CN=$($Record.name),$($destOU)" -domaincontroller $DestDC -EmailAddresses @{remove=$_} 
		        write-output "OK: Removed unecessary email $_"  }
        
        ## Deal with leagacyExchagneDN email addresses
       ## if ($contact.proxyadresses -contains "TOWERADMIN") {write-output "OK: Legacy name sorted."}
         ##   else {
           ##     if($record.LegacyExchangeDN) {{set-adobject  -server $destdomain -identity $contact -credential $creds -add @{'ProxyAddresses'="X500:$($record.legacyexchangedn)"}}
             ##   write-output "OK: Added X500 Proxy address"
               ##     }
               ## }
}


########################################
## Attach to the various environments ##
########################################

## build credentials for the exchange server
if (test-path $file){$pass = get-content $file | convertto-securestring}
else {write-output "Saved user: $($user)."
	(get-credential -Message "Enter password for $($user).  Username is not used.").password | ConvertFrom-SecureString | Out-File $file 
	write-output "Now, run the command again."
	exit
	} 
$creds = new-object -typename system.management.automation.pscredential -argumentlist $user, $pass

## Load up the Necessary Modules
import-module activedirectory
## test for an existing pssession to the target server
$sessions = get-pssession
if ($sessions.computername -contains $destexch) {if ($loud) {write-output "OK: Connecton to exchange environment exists."}}
else {
## if none exist, attach to the 'Destination' Exchange Environment
       try { $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$destexch/PowerShell/ -Credential $creds
            $temp = Import-PSSession $Session -WarningAction SilentlyContinue -DisableNameChecking }
            catch {write-output "Fatal Error: Unable to attach to exchange environment. Exiting."
                    exit }
     }


################################
## Main program starts here   ##
################################

##  get all active users in the source Domain/OU
if ($loud) {write-output "OK: Building Source User Objects"}
##write-output "get-aduser -server $($sourceDomain) -searchbase $($sourceOU) -searchscope onelevel -ldapfilter '(!userAccountControl:1.2.840.113556.1.4.803:=2)' -properties *"
try {$SourceUsers = get-aduser -server $($sourceDomain) -searchbase $($sourceOU) -searchscope subtree -ldapfilter '(!userAccountControl:1.2.840.113556.1.4.803:=2)' -properties * -Erroraction Stop }
    catch { write-output "Error: Fatal Error getting Source Users."
            if ([adsi]::Exists("LDAP://$($sourceDomain)")) {if ($loud) {write-output "OK: Source Domain exists"}}
                else {write-output "Error: Source Domain not found"}
            if ([adsi]::Exists("LDAP://$($sourceOU)")) {if ($loud) {write-output "OK: Source OU exists"}}
                else {write-output "Error: Source OU Not found"}
            write-output "Exiting."
            exit}

## Confirm the Destination AD is reachable and correct:
if ([adsi]::Exists("LDAP://$($destDomain)")) {if ($loud) {write-output "OK: Destination Domain exists"}}
    else {write-output "Error: Destination Domain not found"
    break}
if ([adsi]::Exists("LDAP://$($destOU)")) {if ($loud) {write-output "OK: Destination OU exists"}}
    else {write-output "Error: Destination OU Not found"
    break}

##  Iterate through users and perform tests before continuing
## 1) make sure SMTP address is set. This is to be the primary key for records.
foreach ($user in $SourceUsers) {
    $UT = get-aduser -server $sourcedomain -identity $user -properties *
    if ($UT.emailaddress -eq $null) {
        write-output "Error: E-mail address for $($ut.name) is null. Skipping."
        continue }
## 1.1) check MTA field 
    if ($UT.emailaddress -eq $null) {
        write-output "Error: E-mail address for $($ut.name) is null. Skipping."
        continue }
## 1.2 check the account is enabled
    if ($ut.enabled -eq $Falase) {
        write-output "Error: Account is disabled. Skipping."
        continue }
## 2) test if the users exists in target.
    $DestContact = Get-contact -Domaincontroller $destdc -Identity $UT.name -erroraction silentlycontinue
    $destMailbox = get-mailbox -DomainController $destdc -Identity $ut.name -erroraction silentlycontinue
    if ($destmailbox) {
            if ($loud) {write-output "OK: Mailbox $($ut.name) exists in target OU.  Skipping to next User."}
            Continue }
    elseif ($DestContact) {
           if ($loud) {write-output "OK: Contact $($ut.name) exists in target OU."}
           }
    else { Write-Output "OK: User $($UT.name) not found in destination OU." 
## check smtp address isn't taken:
            if (get-adobject -server $destdomain -properties mail,proxyaddresses -filter {mail -eq $ut.emailaddress -or proxyaddresses -like "smtp:$($ut.emailaddress)"}) {
                    write-output "Error: Email address taken. skipping user $($ut.name)"
                    continue }
## if no, create it in the destination AD
            $temp = new-mailcontact -name $UT.name -ExternalEmailAddress $UT.emailaddress -OrganizationalUnit $destOU -erroraction stop
            Write-output "OK: Created mail contact for $($UT.name)"
## now update the remaining details
            }
        Update-contactrecord $UT
    }
## and end Loop
