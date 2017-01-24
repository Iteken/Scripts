# get users from hackney and create contacts with as much info as possible
import-module activedirectory
add-pssnapin Microsoft.Exchange.Management.PowerShell.E2010

$HCCUsers = get-aduser -server SC-DC1.hackney.local -searchbase "OU=Staff,OU=Users,OU=HCC,DC=hackney,DC=local" -ldapfilter '(!userAccountControl:1.2.840.113556.1.4.803:=2)' -properties Name, DisplayName, givenName, sn, Initials, Office, Department, Description, TelephoneNumber, ipPhone, EmailAddress, samaccountname, Userprincipalname
write-output "Creating Contact objects."
foreach ( $user in $HCCUsers) {
try {$n = get-adobject -identity "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower"
	write-output "OK: Mail Contact $($user.name) found" }
catch { write-output "Warning: Contact $($user.name) Not Found" 
        if ($user.emailaddress -ne $null) {new-mailcontact -name $user.name -ExternalEmailAddress $user.emailaddress -OrganizationalUnit "OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" 
                                              Write-output "OK: Created contact for $($user.name)" }
        else { Write-Output "Error Primary SMTP not set - skipping $($user.name)"} 
        } 
   }

#sleep 15
write-output "Now adding attributes"
foreach ($user in $HCCUsers ) {
    if ($user.emailaddress -ne $null) {
	    $local = get-adobject "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower"
        if ($user.givenname -ne $null) {set-adobject $local -replace @{'givenname'=$user.givenname} }
        if ($user.displayname -ne $null) {set-adobject $local -replace @{'displayname'=$user.displayname} }
        if ($user.sn -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'sn'=$user.sn} }
        if ($user.initials -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'initials'=$user.initials} }   
        if ($user.department -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'department'=$user.department} }
        if ($user.description -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'description'=$user.description} }
        if ($user.telephonenumber -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'telephonenumber'=$user.telephonenumber} }
        if ($user.ipphone -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'ipPhone'=$user.ipphone} }
        if ($user.emailaddress -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'mail'=$user.emailaddress} }
        if ($user.attributeextension1 -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'attributeextension1'=$user.samaccountname} }
        if ($user.attributeextension2 -ne $null) {set-adobject -server pladc01 "CN=$($user.name),OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -replace @{'Attributeextension2'=$user.userprincipalname} } 
        write-output "OK: Updated contact for $($user.name)"
        }
    else {Write-Output "Error: Primary SMTP not set - skipping $($user.name)" }
     }

## now cleanup the local exchange shit 
$contacts = get-mailcontact -organizationalunit "OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower" -resultsize unlimited
foreach($i in $contacts) {
	set-mailcontact $i -emailaddresspolicyenabled $false
	  $i.EmailAddresses |
	    ?{$_.AddressString -like "*@tower.ac.uk"} | %{
		write-output "Removing $_.addressstring"
		Set-Mailcontact $i -EmailAddresses @{remove=$_}
    }
}