## GetLocalUser

param (
    [string]$username = "martin christopher",
    [string]$dc = "nc-pl-dc-1.ncclondon.ac.uk",
    [switch]$loud = $false
    )

## Connect to environments and load credentials
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


function LocateUser ($user) {
# 1 Check for a local Mailbox belongong to the username
    $m = get-mailbox $user -erroraction silentlycontinue
    if ($m) {write-output "OK: Found mailbox for $($m.name) with alias $($m.alias)"
                return ($m)} 
# 2 if not - have a look for a contcat with similar information
    $c = get-contact $user -erroraction silentlycontinue
    if ($c) {write-output "OK: Found contact for $($c.name) with alias $($c.alias)"
                return $c }
#3 if not, try removing the space
    $cs= get-contact ($user -replace (" ")) -erroraction silentlycontinue
    if ($cs) {return $cs }

#4a finally search adobjects for something matching $username in either
    $ado = get-adobject -server $dc -filter {mailnickname -eq $user}
        if ($ado) {return $ado}
# final
    
}

if ($username -eq $null) {write-output "Error: No username specified. Exiting."
                            exit }

$return = locateuser $username
if ($return -eq $null) {Write-output "Fatal: Recipient not found."
                            exit}
elseif ($return.recipienttype -eq "UserMailbox") {write-output "Type: Mailbox."}
elseif ($return.recipienttype -eq "MailContact") {Write-output "Type: Contact."}
write-output $return.id