# get managers, then get everyoen and load them into arrays
$managers = get-aduser -searchbase "OU=OU Staff Accounts,DC=admin,DC=tower" -filter {directreports -like '*'} -Properties *
#$allstaff = get-aduser -searchbase "OU=OU Staff Accounts,DC=admin,DC=tower" -filter * -Properties *

# loop through managers and 
# for each direect report get their real name
foreach ($person in $managers) { 
    write-output $person.Name
    foreach ($report in $person.directreports) {
        $ReportINfo = get-aduser $report -properties *
        write-output "$($reportinfo.name); $($reportinfo.title);$($reportinfo.department);$($reportinfo.description);$($reportinfo.Officephone);$($reportinfo.office);$($reportinfo.company);$((get-aduser $reportinfo.manager).name)" }
    write-output ""
    }
    
