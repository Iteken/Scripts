try {$n = get-adobject -identity "CN=Kirk Gould,OU=HCC Contacts,OU=OU Contacts,DC=admin,DC=tower"
	write-output "User found" }
catch { write-output "User Not Found" } 