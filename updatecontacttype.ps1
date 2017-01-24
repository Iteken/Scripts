## Updatecontacttypes

# set-adobject -replace @{'mAPIrecipient' = "TRUE"}
# set-adobject -replace @{'mxExchMasterAccountSid' = source user SID}
# set-adobject -replace @{'msExchOriginatingForest' = "admin.tower"}
# set-adobject -replace @{'msExchRecipientTypeDisplay' = "-1073741818"}
# set-adobject -replace @{'msExchRecipientTypeDetails' = "32768"}

# get accounts:
$Contacts = get-adobject -SearchBase "OU=Toweradmin,OU=OU Contacts,DC=ncclondon,dc=ac,dc=uk" -filter * -properties *
foreach ($c in $contacts) {
    $sid = (get-adobject -server pladc01.admin.tower -filter {name -eq $c.name} -Properties objectsid).objectSid
    write-output $sid

    }
    
