## pull filewave users from AD

$domain = "students.tower"
$server = "PLAsql01"
$database = "THCLive"
$querytable = "dbo.THC_ActiveDirectory"
$OUpath = "OU=Created in 2016,OU=OU Students,DC=students,DC=tower"
$Homepath = "\\plafilewave10\StudentData\"
$BaseDir = $homepath
$NBDomain = "TOWERSTUDENTS"
$FQDomain = $domain

##   Get-ADUser -Server students.tower -SearchBase "OU=Created in 2015,OU=OU Students,DC=students,DC=tower" -SearchScope Subtree -filter * -properties name, Homedirectory | ForEach-Object { if ($_.Homedirectory -like "\\plafilewave*" ) {Write-Output "$($_.name), $($_.HomeDirectory)" } }
## Search ebs for the user ID from the ?


function DirOwner ($studentid, $action) {
    $fulldir = $basedir + $studentid
    $dir = get-item $fulldir 
## Check owner
## else set it
    if ( (Get-Owner -path $dir.fullname).Owner.AccountName -like "*$($dir.name)") {
         $Outputstring +=  "$($dir.name) - Owner correct"
        }
    else { $Outputstring +=  "Owner for $($dir.name) is wrong." 
        if ($action -eq "fix") {
        ## fix if told to
            set-owner -path $dir.fullname -account "TOWERSTUDENTS\$($dir.name)"
            }
        } 
    }

Function DirFullControl ($studentid, $actionarg) {
## Check to see if the student has full control of the directory
    $fulldir = $basedir + $studentid
    $dir = get-item $fulldir
    $dirAce = Get-Ace -ExcludeInherited -Path $fulldir
    $count = 0
    foreach ($line in $dirace) {
        if ($line.account -eq "$($NBDomain)\$($studentid)") {
            $count ++
            if ($line.AccessRights -eq "FullControl") {  $Outputstring += "$($studentid) Has Full Control."}
            else { $Outputstring +=  "Access error on Directory $fulldir.  " }
            }
    }
    if ($count -eq 0) { 
         $Outputstring +=  "Error: No user permission $($studentid)"
        if ($actionarg -eq "fix") {
            add-ace -path $fulldir -account "$($NBDomain)\$($studentid)" -accessRights "FullControl"
            $Outputstring +=  "Added FullControl for user $($studentid).  "
            }
        }
}
## 

## $query = "SELECT DISTINCT PEOPLE_UNITS.PERSON_CODE FROM PEOPLE_UNITS INNER JOIN UNIT_INSTANCE_OCCURRENCES ON PEOPLE_UNITS.UIO_ID = UNIT_INSTANCE_OCCURRENCES.UIO_ID WHERE (PEOPLE_UNITS.UNIT_TYPE = N'r') and progress_code = 'act' and calocc_code = '15/16'and OFFERING_ORGANISATION = 'creative arts'  "

$query = "select distinct student_id from dbo.THC_ActiveDirectory where aos_code in ('Q80034','Q80035','Q80036','Q80037','Q80038A','Q80038B','Q80039A','Q80039B','Q80040','Q80041','Q60323','Q60322','Q70234A','Q70234B','Q80300AP','Q80301AR')"

$sqloutput = invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10
$count=0
foreach ( $student in $sqloutput ) {
    $user = get-aduser -server "Students.tower" -identity $student.student_id -properties Name, Homedirectory 
    $Outputstring = "Processing: $($user.name).  "
        $studentpath = "$($homepath)$($student.student_id)"
        ## Update profile
        if ($user.HomeDirectory -notlike "\\plafilewave10*" ) {
                try { Set-ADuser -server $domain -Identity $student.student_id -homedirectory $studentpath
                $Outputstring += "Updated Profile path." }
                catch { $Outputstring += "Failed to set path for $($student.student_id)" }
            }
        else { $Outputstring +=  "Profile path already set." }
        ## test for the new path
        if (Test-Path $studentpath ) {$OutputString +=  "User Directory exists.  "}
        else  { $Outputstring +=  "User Directory not found - creting it.  " 
                try {New-Item -ItemType directory -path $studentpath
                        $Outputstring += "Created Path ok."}
                catch {$OutputString +=  "Create-path failed - exiting.  "
                        break}
                }
        ## test/fix permissions
        dirowner $student.student_id fix
        dirfullcontrol $student.student_id fix

    $count ++
    write-output $OutputString 
    }

write-output $count