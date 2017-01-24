$BaseDir = "\\students.tower\dfs\students\"
$NBDomain = "TOWERSTUDENTS"
$FQDomain = "Students.tower"

function DirOwner ($studentid, $action) {
    $fulldir = $basedir + $studentid
    $dir = get-item $fulldir 
## Check owner
## else set it
    if ( (Get-Owner -path $dir.fullname).Owner.AccountName -like "*$($dir.name)") {
        write-output "$($dir.name) - Owner correct"
        }
    else {write-output "Owner for $($dir.name) is wrong." 
        if ($action -eq "fix") {
        ## fix if told to
            write-output "... Fixing."
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
            if ($line.AccessRights -eq "FullControl") { Write-output "$($studentid) Has Full Control."}
            else { write-output "Access error on Directory $fulldir" }
            }
    }
    if ($count -eq 0) { 
        write-output "Error: No user permission $($studentid)"
        if ($actionarg -eq "fix") {
            add-ace -path $fulldir -account "$($NBDomain)\$($studentid)" -accessRights "FullControl"
            Write-Output "Added FullControl for user $($studentid)"
            }
        }
}

function FixUsers ($filepath) {
    $file = get-content $filepath
    foreach ($line in $file) {
        if ( $line -like "Error: Failed to set owner*" ) {
            dirowner $line.substring($line.length-7) fix
            dirfullcontrol $line.substring($line.length-7) fix
                }
            }
    }  

