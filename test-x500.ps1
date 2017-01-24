# compare x500, legacyexcahngedn and all otehr adresses between domains
# report, and maybe fix.

param (
    [string]$Username = "mchristopher",
    [string]$SourceDomain = "Admin.tower",
    [string]$DestDomain = "ncclondon.ac.uk",
    [switch]$loud=$false,
    [switch]$fix=$false
    )

function testaddress ($Address) {
    $match = 0
    foreach ($pa in $destuser.proxyaddresses) {
        if ($pa -like "*$($address)*") { 
                if ($loud) {write-output "Found Address on $($destdomain)"}
                $match = 1} 
        }
    if ($match -eq 0) {
        write-output "Warning: missing $($address) for user $username"
        if ($fix) {write-output "Fixing...." 
                try {set-aduser $username -server $destdomain -credential $creds -add @{'ProxyAddresses'="x500:$($address)"}
                    write-output "Fixed."}
                catch {write-output "Error updating x500 address"}
                }
        }
}

    $Credfile = "o:\scripts\password.NCC"
    $Creduser = "ncclondon\mchristopher"

if (test-path $Credfile){$pass = get-content $Credfile | convertto-securestring}
else {write-output "Saved user: $($Creduser)."
	(get-credential -Message "Enter password for $($Creduser).  Username is not used.").password | ConvertFrom-SecureString | Out-File $Credfile 
	write-output "Now, run the command again."
	exit
	} 
$creds = new-object -typename system.management.automation.pscredential -argumentlist $Creduser, $pass


$sourceuser = get-aduser $username -properties legacyexchangedn,proxyaddresses
$destuser = get-aduser -server $destdomain $username -properties proxyaddresses

if ($loud) {Write-output "$($sourceuser.legacyexchangedn)"}
testaddress $($sourceuser.legacyexchangedn)
foreach ($p in $sourceuser.proxyaddresses) {
    if ($p -like "*x500:*") {  
        if ($loud) {Write-output ("$($p)" -replace("x500:") )}
        testaddress ("$($p)" -replace("x500:") )
        } 
    }


   
