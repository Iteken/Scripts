##  setup parameters
## Input / setup parameters 
param (
    [Parameter()] [string]$sourceDC = "PLADC01.admin.tower",
    [Parameter()] [string]$sourceOU = "OU=OU Groups,DC=admin,DC=tower",
    [Parameter()] [string]$destDC = "nc-pl-dc-1.ncclondon.ac.uk",
    [Parameter()] [string]$destOU = "OU=Groups,OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk",
## variables for caching credentials
    [string]$file = "o:\scripts\password.NCC",
    [string]$user = "mchristopher@ncclondon.ac.uk",
    [Parameter(Mandatory=$false)] [switch]$Loud
    )

## Programable constants
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

##############
## Fuctions ##
##############


function LocateUser ($user) {
# 1 Check for a local Mailbox belongong to the input variable
    $m = get-mailbox  -domaincontroller $destdc $user -erroraction silentlycontinue
    if ($m) {return $m} 
# 2 if not - have a look for a contcat with similar information
    $c = get-contact  -domaincontroller $destdc $user -erroraction silentlycontinue
    if ($c) {return $c }
#3 if not, try removing the space
    $cs= get-contact ($user -replace (" "))  -domaincontroller $destdc -erroraction silentlycontinue
    if ($cs) {return $cs }
}

## CheckGroup
## Check if the mail-enabled group exists.  if not, create it then update the information.
function checkgroup ($group) {
    $targetgroup = get-distributiongroup -domaincontroller $DestDC $group.Name -erroraction 'Silentlycontinue'
    if ($targetgroup) {write-output "OK: Group $($group.name) exists in target domain" } 
    else { if($loud) {write-output "Error: Group $($group.name) not found."}
            try { New-DistributionGroup -DomainController $destDC -OrganizationalUnit $destOU -name $group.Name -samaccountname $group.name -Alias $group.Alias `
                        -displayname $group.DisplayName -MemberJoinRestriction $group.MemberJoinRestriction -MemberDepartRestriction $group.MemberDepartRestriction
                    write-output "OK: Created Distribution group $($group.name)"}
                catch {write-output "Error: Failed to create Group."}
        }
   # this may not be necessary 
   # Set-adobject -server $destdc "CN=$($group.name),$($destOU)" -add @{'ProxyAddresses' = "X500=$($group.LegacyExchangeDN)"} -credential $creds
}

## UpdateGroup
## add a few things to the group
## Iterate through group members and add their ncc contacts to the group.
function UpdateGroupMembers ($group) {
    $targetgroup = get-distributiongroup -domaincontroller $DestDC $group.Name -erroraction 'Silentlycontinue'
    $members = Get-DistributionGroupMember -domaincontroller $sourceDC $group.Name
    foreach ($member in $members) {
            $membername = $member.name
            $returneduser = locateuser ($membername)
            if ($returneduser.id -NE $null) {
                    write-output "Add-DistributionGroupMember -DomainController $($destDC) -Identity $($targetgroup.name) -Member $($returneduser.id)"
                    Add-DistributionGroupMember -DomainController $destDC -Identity $targetgroup.name -Member $returneduser.id  -erroraction Silentlycontinue 
                    }   
         }
} 

## UserGroupCheck
## Iterate through users in a group and confirm they are a member of the source group

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

################################
## Main program starts here   ##
################################

## Load Source Groups
if ($loud) {Write-output "OK: Building Source Groups"}

try {$SourceGroups = get-distributiongroup -domaincontroller $SourceDC -OrganizationalUnit $SourceOU }
    catch { write-output "Error: Fatal Error getting source groups."
            if ([adsi]::Exists("LDAP://$($sourceDC)")) {if ($loud) {write-output "OK: Source DC exists"}}
                else {write-output "Error: Source DC not found"}
            if ([adsi]::Exists("LDAP://$($sourceOU)")) {if ($loud) {write-output "OK: Source OU exists"}}
                else {write-output "Error: Source OU Not found"}
            write-output "Exiting."
            exit}
Write-Output "OK: Loaded $(($sourcegroups).count) Groups from $($SourceDC)"

## Iterate through the list of groups, check stuff then do stuff
foreach ($group in $SourceGroups) {
## Run CheckOwner - NOT YET
    if ($group.managedby -eq "") {
            write-output "Error: Group owner is blank. Moving to next."
               continue}

    checkgroup $group
    updategroupmembers $group
# end main loop
    }