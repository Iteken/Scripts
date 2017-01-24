$allstaff = get-aduser -searchbase "OU=OU Staff Accounts,DC=admin,DC=tower" -filter * -Properties *
foreach ($person in $allstaff) {
    if ($person.manager -eq $null) {write-output "$($person.name); $($person.title);$($person.department);$($person.description);$($person.Officephone);$($person.office);$($person.company)"}
    else {write-output "$($person.name); $($person.title);$($person.department);$($person.description);$($person.Officephone);$($person.office);$($person.company);$((get-aduser $person.manager).name)" }
    }