param (
    [parameter(mandatory=$true)][string]$username,
    [string]$destDC = "nc-pl-dc-1.ncclondon.ac.uk",
    [string]$sourceDC = "pladc01.admin.tower",
    [string]$destexch = "nc-pl-mail-1.ncclondon.ac.uk",
    [switch]$loud = $false
    )

$GArray = new-object system.collections.arraylist
## Connect to environments and load credentials
## build credentials for the exchange server
    $Credfile = "o:\scripts\password.NCC"
    $Creduser = "ncclondon\mchristopher"

## Connect to environments and load credentials
## build credentials for the exchange server
if (test-path $credfile){$pass = get-content $credfile | convertto-securestring}
else {write-output "Saved user: $($creduser)."
	(get-credential -Message "Enter password for $($creduser).  Username is not used.").password | ConvertFrom-SecureString | Out-File $credfile 
	write-output "Now, run the command again."
	exit
	} 
$creds = new-object -typename system.management.automation.pscredential -argumentlist $creduser, $pass

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

# Find NCC user mailbox and exit if it's not
$destU = get-mailbox -DomainController $destDC $username -ErrorAction stop
$sourceU = get-aduser -server $SourceDC $username -properties memberof -ErrorAction stop
# get admin.tower user
# get groups & iterate
foreach ($SourceG in $SourceU.memberof) {
        #write-output $SourceG
        # identifying properties:  legacyexcahngeDN, mail, mailnickname and msexchangeversion
        try {$g = get-adgroup -server $sourceDC $sourceG -properties msexchversion -ErrorAction silentlycontinue
            if ($g.msexchversion -ne $null) {
                # add user to it on NCC
                if (get-distributiongroup -DomainController $destDC -Identity $g.name -ErrorAction silentlycontinue) {
                            Add-DistributionGroupMember -DomainController $destDC -Identity $g.name -Member $username -ErrorAction silentlycontinue 
                            $GArray += $($g.name)
                            }
                else {write-output "Error: Distribution group $g missing from Destination domain."}}
             }
            Catch {}
       }
write-output "Mail Enabled Groups Updated" "---------------------------" 
write-output $garray
