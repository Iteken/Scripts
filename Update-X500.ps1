param (
    [switch]$user = $false,
    [switch]$group = $false
)
## Connect to environments and load credentials
## build credentials for the exchange server
    $Credfile = "o:\scripts\password.NCC"
    $Creduser = "ncclondon\mchristopher"

if (test-path $Credfile){$pass = get-content $Credfile | convertto-securestring}
else {write-output "Saved user: $($Creduser)."
	(get-credential -Message "Enter password for $($Creduser).  Username is not used.").password | ConvertFrom-SecureString | Out-File $Credfile 
	write-output "Now, run the command again."
	exit
	} 
$creds = new-object -typename system.management.automation.pscredential -argumentlist $Creduser, $pass

if ($user){
    ## Update THC X500 addresses
    $users = Get-ADObject -searchbase "OU=OU Staff accounts,DC=admin,DC=tower" -filter * -properties LegacyExchangeDN
    foreach ($u in $users) {
        try {get-adobject "cn=$($u.name),OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -ErrorAction silentlycontinue 
            write-output "$($u.name) Exists."
            Set-ADObject "cn=$($u.name),OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -add @{'ProxyAddresses'="X500:$($u.legacyexchangedn)" }
            write-output "added X500:$($u.legacyexchangedn)"  }
        catch {Write-Output "Error: User not found on target domain. Ignoring."}
        }
}

if ($group) {
    ## Update THC Groups
    $groups = Get-ADObject -searchbase "OU=OU Groups,DC=admin,DC=tower" -filter {(mail -like "*") -and (objectclass -eq "group")}  -properties LegacyExchangeDN
    foreach ($g in $groups) {
        #try {
        get-adobject "cn=$($g.name),OU=Groups,OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -ErrorAction silentlycontinue 
            write-output "$($g.name) Exists."
            set-adobject "cn=$($g.name),OU=Groups,OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -remove @{'ProxyAddresses'="X500:/o=Tower Hamlets College/ou=Exchange Administrative Group (FYDIBOHF23SPDLT)/cn=Recipients/cn=Iain Collins098"}
            Set-ADObject "cn=$($g.name),OU=Groups,OU=TOWERADMIN,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -add @{'ProxyAddresses'="X500:$($g.legacyexchangedn)" }
            write-output "added X500:$($g.legacyexchangedn)"  
            #}
        #catch {Write-Output "Error: Group not found on target domain. Ignoring."}
        }
}

if ($user) {
    ## Update Hackney X500 adresses
    $users = Get-ADObject -searchbase "OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -filter * -properties LegacyExchangeDN
    foreach ($u in $users) {
        try {$a= get-adobject "cn=$($u.name),OU=HACKNEY,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -ErrorAction silentlycontinue 
                write-output "$($u.name) Exists."
                Set-ADObject "cn=$($u.name),OU=HACKNEY,OU=OU Contacts,DC=NCCLondon,DC=ac,DC=uk" -server ncclondon.ac.uk -Credential $creds -add @{'ProxyAddresses'="X500:$($u.legacyexchangedn)"}
                write-output "added X500:$($u.legacyexchangedn)"}
            catch {Write-Output "Error: User not found on target domain. Ignoring."
            continue}
        }
    }