param (
    [string]$file = "o:\scripts\password.MSOL",
    [string]$user = "sysadmin@ncclondon.onmicrosoft.com",
    [switch]$msol = $false,
    [switch]$exch = $false
    )
if (test-path $file){$pass = get-content $file | convertto-securestring}
else {write-output "Saved user: $($user)."
	(get-credential -Message "Enter password for future refrence.  Username is not used.").password | ConvertFrom-SecureString | Out-File $file 
	write-output "Now, run the command again."
	exit
	} 
$creds = new-object -typename system.management.automation.pscredential -argumentlist $user, $pass

if ($msol) {connect-msolservice -Credential $creds}
if ($exch) {$session = new-pssession -configurationname microsoft.exchange -connectionURI https://outlook.office365.com/powershell-liveid -credential $creds -authentication Basic -allowRedirection
            import-pssession $session}