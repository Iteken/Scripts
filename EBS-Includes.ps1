
<#
 * EBS powershell library version 2
 * 
 * Copyright (c) 2015 Martin Christopher <mchristopher@tower.ac.uk>
 * 
 * All rights reserved. No warranty, explicit or implicit, provided.
 #>

 <# 
 * 20/8/15 - added a new dependancy to the NTFSSecurity modules
 * from http://bit.ly/1zIDAT
 * MC
 #>

 <# 
 *
 * Adding new code for 2016
 * Changed OU
 * Adding Move/Enable account code
 * Renamed functions to more sensible names
 *
 #>

## Build and define all the common variables up here
## library/module must be re-loaded if any of this changes.
$domain = "students.tower"
$NBDomain = "TOWERSTUDENTS"
$server = "PLAsql01"
$database = "THCLive"
$querytable = "dbo.THC_ActiveDirectory"
$querycolumns = "student_id,aos_code,sessiontitle,mobile_phone_no,birth_dt,Forename,surname"
$year = "2016"
$grouppath = "OU=Created in $($year),OU=OU Groups,DC=students,DC=tower"
$OUpath = "OU=Created in $($year),OU=OU Students,DC=students,DC=tower"
## $logonscript = "students.bat"
$commongroups = "Internet Students", "Students" 
$BaseDir = "\\students.tower\dfs\students\"
$ProfileDir = "\\students.tower\dfs\profiles\"
$users = 0
$Errorusers = ""
 
function ebs-newuser ($user) {
## take a user id
## grab all the info from a db
## create the user
## and put them in default groups
    $uquery = "select distinct forename,surname,birth_dt,mobile_phone_no from $querytable where student_id = '$user'"
    $usqloutput = invoke-sqlcmd -query $uquery -Serverinstance $server -Database $database -Querytimeout 10
    $udesc = $usqloutput.Forename + " " + $usqloutput.surname 
    $udisp = $udesc + " (" + $user + ")"
    $ubdate = $usqloutput.birth_dt
    $uday= $ubdate.day
    $umonth = $ubdate.month
    $uYear = $ubdate.year
    $ubpasswd = $usqloutput.birth_dt.tostring("ddMMyyyy")
    $uPasswd = convertto-securestring -String $ubpasswd -asplaintext -force
    $email = "$user@students.tower.ac.uk"
    $homedir = "$($basedir)$user"
    $profiledir = "$($Profiledir)$user"
    $subfolders = "Desktop","My Documents","Recent"
    $links = "Computer.lnk", "Google Chrome.lnk"

## Create the user      
    try {new-aduser -server $domain -Name $user -path $OUPath -description $udesc -displayname $udisp -emailaddress $email -homedirectory $homedir -homedrive "F" `
            -UserPrincipalName $email -givenname $usqloutput.Forename -surname $usqloutput.surname -mobilephone $usqloutput.mobile_phone_no `
            -Accountpassword $uPasswd -Enabled $true -ChangePasswordAtLogon $true -ProfilePath $profiledir
        write-output "OK: User $($user) created."}
    catch {write-output "Failed to create user $($user)."
          write-output $error[0].ToString() 
          return}
# Fix the target, proxy & nick
    try {set-aduser -server $domain -identity $user -add @{"mailNickname"="$user"}
         set-aduser -server $domain -identity $user -add @{"proxyaddresses"="SMTP:$email"}
         set-aduser -server $domain -identity $user -add @{"targetaddress"="$email"}
         write-output "OK: Extended user attributes succesfully."}
    catch { write-output "Error: Failed to extend user attributes.  Investigate." }
# Add the user to default groups
    foreach ($group in $commongroups) {
       try { add-adgroupmember -identity $group -members $user -server $domain
             write-output "OK: Added $($user) to $($group)."}
       catch {write-output "Warning: Failed to add $($user) to $($group)."}
       } 

## Create Home Directories
        Start-Sleep 10
## And set owner + permissions
        $studentpath = "$basedir$($user)"
        $Account = "TOWERSTUDENTS\" + $user
        ## double-check user
        try { $a = Get-ADUser -server students.tower -Identity $user }
        catch { write-output "Error: User Not Found $($user)"
            return}
        ## Create directory
        try { $a = new-item -ItemType directory -path $studentpath
                write-output "OK: Created home directory $($studentpath)"}
        catch { write-output "Error: Failed to create $($studentpath)" 
                $Usererror = 1}
        ## set owner
        try { Set-Owner -path $studentpath -account "TOWERSTUDENTS\$($user)" 
              write-output "OK: Set owner to $($user)"}
        catch {"Error: Failed to set owner for $($studentpath)"
                $usererror = 1}
        ## set full control
        try { add-ace -path $studentpath -Account "TOWERSTUDENTS\$($user)" -AccessRights FullControl 
                write-output "OK:Set security permissions for $Account" }
        catch {"Error: Failed to set permissions for $($studentpath)" 
                $usererror = 1}
        if ( $usererror = 1) { $ErrorUsers += $user }
   }

function ebs-fixuser ($results) {
    ##  Main program function to fix a user

    ## check all the groups exist
    ##  and putting the user into any "P" groups it should be in.
    foreach ($line in $results) 
        { 
        # Filter out P's only:
        if ( $line.aos_code.startswith("P") ) 
              {
        # check the group exists 
            try { $fake = get-adgroup -identity $line.aos_code -server $domain 
                #check the user is part of it
                    $groupmembers = @( get-adgroupmember -identity $line.aos_code -server $domain | get-aduser -server $domain | select name )
                    if ( $groupmembers -match $line.student_id )
                      { write-output "OK: $($line.student_id) in Group $($line.aos_code) - $($line.SessionTitle)"}  
                    else
                      { write-output "Warning: $($line.student_id) not in Group $($line.aos_code) - $($line.SessionTitle)"
                      ebs-addtogroup $line.student_id $line.aos_code } 
                }          
             catch {
                # if the group doesn't exist then create it
                write-output "Warning: Group $($line.aos_code) missing."
                ebs-newgroup $line.aos_code $line.sessiontitle
                # then add the user to it after a snooze
                start-sleep -s 5
                ebs-addtogroup $line.student_id $line.aos_code
                   }
              }
        }
## now check their home directory for permissions and ownership an dfix if necessary

    

    }
    
function ebs-testgroup($results) {
    ## main program function to identify and test each "P" group for id membership
    ## and report the output in an easily readable format
    foreach ($line in $results) 
        { 
        # extract only the P course codes
            if ( $line.aos_code.startswith("P") ) 
              {
            # check the group exists 
                try { $groupdata = get-adgroup -identity $line.aos_code -server $domain 
                    # test if the user is a group member
                    $groupmembers = @( get-adgroupmember -identity $line.aos_code -server $domain | get-aduser -server $domain | select name )
                    if ( $groupmembers -match $line.student_id )
                          { write-output "  OK: $($line.student_id) in Group $($line.aos_code) - $($line.SessionTitle)" }
                    else
                          { write-output "  Warning: $($line.student_id) not in Group $($line.aos_code) - $($line.SessionTitle)" }
                    # Write the output
                    }
                 catch {
                    # if the group doesn't exist do this
                            write-output "  Error: $($line.student_id) Group $($line.aos_code) Missing."
                  }
              }
         }
      }

function ebs-newgroup ($code, $course){
        ##  Creates Groups within AD
        try { new-adgroup -name $code -groupscope "Universal" -server $domain -path $grouppath -description $course
              write-output "OK: Created Group $($code) sucessfully." }
        catch { write-output "Failed to create group $($code)."
                write-output $error[0].ToString() + $error[0].InvocationInfo.PositionMessage 
                $errors += 1}
    }
    
function ebs-addtogroup ($user,$group) {
        ## adds a user id to a group in AD
        try { add-adgroupmember -identity $group -members $user -server $domain
               write-output "OK: Added $($user) to $($group)" }
        catch { write-output "Failed to add user $($user) to group $($group)."
                write-output $error[0].ToString() + $error[0].InvocationInfo.PositionMessage }
    }

function ebs-testuser ($user,$actionarg) {

    # stash location
    push-location
    # user test function to call from cli.
    # replaces the ebs user 'script' mess
    $query = "select $querycolumns from $querytable where student_id = '$user'"
    $sqloutput = invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10
        ## do a little testing of the account    
        if ( $sqloutput -eq $null ) 
            { write-output "Error: User does not exist in EBS. " 
                       return }
        else { write-output "OK: User $($user) exists in EBS." }
        ## since some SQL has been returned - act on it.
        ## Test if the ad account is there
        $eue = (get-aduser -server $domain -filter {samaccountname -eq $user})
        ## write-output $eue
        if ( $eue -eq $null ) {
            ## null response = user not found
            if ($actionarg -eq "create") {
                    ebs-newuser $user
                    write-output "OK: User $($user) created."
                    ebs-fixuser $sqloutput }     
            else {write-output "Error: Account missing from AD and create not specified. Exiting." 
                   return} }
       else {
            ## the user does exist in AD but may need work.
            ## now perform the action as required
            if ( $actionarg -eq "fix" ) { 
                ebs-testuserstate $user $actionarg
                write-output "Fixing User group membership..."
                ebs-FixUser $sqloutput 
                }
            elseif ($actionarg -eq "create" ) {
                write-output "Warning: Account $($user) already esists." }
            else { write-output "Testing user."
                ebs-testuserstate $user
                ebs-testgroup $sqloutput }
        }       
    # close and end
    pop-location
    }

Function ebs-testuserstate ($studentid, $actionarg) {
# Function to test a user's ou & enabled state
# and fix it if necessary
$student = get-aduser $studentid -server "$($domain)" -properties profilepath
# check for a profile
if ($student.profilepath -like "$($ProfileDir)*") { write-output "OK: Student Profile correct"}
else {write-output "Warning: Profile path wrong."
    if ($actionarg -eq "fix") {set-aduser $student -server "$($domain)" -ProfilePath "$($profileDir)$($Studentid)"
           write-output "OK: Set Profile to $($profileDir)$($Studentid)" }
    }
# Check if the student account is enabled & fix if necessary
if ($student.enabled) {write-output "OK: Student is enabled"}
else { Write-output "Warning: Student is disabled."
    if ($actionarg -eq "fix") {Enable-ADAccount $student
           write-output "OK: Enabled Student Account"}
        }
# check OU contains 2016 and move/fix if necessary
# this must be the last step as it changes the $student object
if ($student.distinguishedname -like "*$($year)*") {write-output "OK: Student in correct OU"}
else {write-output "Warning: Student in Wrong OU"
    if ($actionarg -eq "fix") {
        Move-adobject $student -TargetPath $oupath
        write-output "OK: Student moved OU $($oupath)"}
     }
# Test/fix directory ownership
EBS-Testhome $($studentid) $($actionarg)
# end of function
}

function ebs-testhomedir ($studentid, $action) {
    $fulldir = $basedir + $studentid
## test for the folder and create it if necessary)
    if (test-path $fulldir) {$dir = get-item $fulldir }
    else {  
        if (($action -eq "fix") -or ($action -eq "Create")) {
            $a = New-Item -itemtype directory -path $fulldir
            write-output "Warning: Created home directory"
            $dir = get-item $fulldir }
        else {write-output "Error: Directory not found and Fix/Create not specified"
            return}
        }
## Check owner
## else set it
    if ( (Get-Owner -path $dir.fullname).Owner.AccountName -like "*$($dir.name)") {
        write-output "OK: $($dir.name) - Owner correct"
        }
    else {write-output "Warning: Owner for $($dir.name) is wrong." 
        if ($action -eq "fix") {
        ## fix if told to
            set-owner -path $dir.fullname -account "TOWERSTUDENTS\$($dir.name)"
            write-output "OK: Fixed folder ownership for $($studentid)"
            }
        } 
## test for the folder and create it if necessary)
    if (test-path $fulldir) {$dir = get-item $fulldir }
    else {$a = New-Item -itemtype directory -path $fulldir
            write-output "Warning: Created home directory"}
    $dirAce = Get-Ace -ExcludeInherited -Path $fulldir
    $count = 0
    foreach ($line in $dirace) {
        if ($line.account -eq "$($NBDomain)\$($studentid)") {
            $count ++
            if ($line.AccessRights -eq "FullControl") { Write-output "OK: $($studentid) Has Full Control."}
            else { write-output "warning: Access error on Directory $fulldir" }
            }
    }
    if ($count -eq 0) { 
        write-output "Error: No user permission $($studentid)"
        if ($action -eq "fix") {
            add-ace -path $fulldir -account "$($NBDomain)\$($studentid)" -accessRights "FullControl"
            Write-Output "OK: Added FullControl for user $($studentid)"
            }
        }
}
function ebs-nightlyjob ($action = "test", $emailto = "ebsreport@tower.ac.uk"){
## Wrapper function to test users added to EBS in the last day.
## Designed to be run every night to create the last day's users.
$emailfrom = "ebs-script@tower.ac.uk"
$subject = "EBS Script Report  " + (get-date -format dd/MM/yyyy) + " : " + $action
$emailbody = ebs-testfromdate (get-date).adddays(-1).tostring("yyyyMMdd") $action                                                                                     
Send-MailMessage -from $emailfrom -to $emailto -Subject $subject -Body ( $emailbody | out-string)  -smtpserver smtprelay
}

function ebs-testfromdate ($startdate, $actionarg) {
## wrapper function called by ebs-nightlyjob
## Queries all users created since $startdate and performs $actionarg on them
    push-location
    write-output "Processing EBS database changes after $($startdate)"
    $query = "select distinct student_id from $querytable where date_entered >= '$($startdate)' order by student_id"    
    #ebs-testfromdatefunc (invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10) $actionarg
    $sqlobject = invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10
    write-output "Performing action $($actionarg) on users created after $($startdate)."
    foreach ( $user in $sqlobject ) { 
        $users += 1
        $userid = $user.student_id
        ebs-testuser $userid $actionarg
    }
    write-output "`r`n Processed $($users) users." $actionarg
    pop-location
}


function ebs-testfromdatefunc ($sqlobject,$actionarg) {
## wrapper function part of the date / daily check chain
## tests each user in the SQL query array in turn and sorts them out.
## NOT USED ANY MORE
    write-output "Performing action $($actionarg)."
    foreach ( $user in $sqlobject ) { 
        $users += 1
        $userid = $user.student_id
        ebs-testuser $userid $actionarg
    }
}

function ebs-OLDtestfromdatefunc ($sqlobject,$actionarg) {
## OLD OLD OLD OLD OLD
## wrapper function part of the date / daily check chain
## tests each user in the SQL query array in turn and sorts them out.
## depreciated
    write-output "Performing action $($actionarg)."
    foreach ( $user in $sqlobject ) { 
        $users += 1
        $userid = $user.student_id
        $eue = ebs-adtest $userid $actionarg
        write-output $eue
        $query = "select $querycolumns from $querytable where student_id = '$userid'"
        $sqloutput = invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10
        if ( $eue -like "OK:*" ) {
                ## build a new sql object with the course info
                    ## if fix, fix it
                        if ( ($actionarg -eq "fix") -or ($actionarg -eq "create") ) 
                            {ebs-fixuser $sqloutput }
                        else {ebs-testgroup $sqloutput }
                    }
        else {
        ## if it doesn't exist, test for create then create them
            if ( $actionarg -contains "create" ) {
                if ( $eue -like "Warning:*" ) {
                       ebs-newuser $userid
                       write-output "OK: User ID $($userid) Created."
                       ebs-fixuser $sqloutput
                     }
            }
       }
       }
    write-output "`r`n Processed $($users) users." $actionarg
    write-output "`r`n Erros with these users - recheck: " $Errorusers
    }


function ebs-testfromdate2 ($startdate, $actionarg) {
$correct = 0
$wrong = 0
## wrapper function called by ebs-nightlyjob
## Queries all users created since $startdate and performs $actionarg on them
    push-location
    write-output "Processing EBS database changes after $($startdate)"
    $query = "select distinct student_id from $querytable where date_entered >= '$($startdate)' order by student_id"    
    #ebs-testfromdatefunc (invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10) $actionarg
    $sqlobject = invoke-sqlcmd -query $query -Serverinstance $server -Database $database -Querytimeout 10
    foreach ( $user in $sqlobject ) { 
        try {$a = get-aduser $user.student_id -server students.tower 
##            write-output "OK: Student $($user.student_id) exists."
             $correct ++}
        catch {write-output "ERROR: Student $($user.student_id) not found in AD."
                if ($actionarg -eq "fix") {ebs-testuser $user.student_id fix}
              $wrong ++}
    }
    write-output "$($correct) users are Correct."
    Write-Output "$($wrong) users are wrong."
    pop-location
}


