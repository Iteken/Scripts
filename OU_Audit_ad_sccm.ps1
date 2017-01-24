## create a output table of an OU's contents
## perform various tests of each object
## eventually try to query sccm and topdesk databases
Push-Location

## input to be a cli argument equating to a room number
## or a request-input

$roomin = read-host -Prompt "Please enter a room number:" 

$nl = [environment]::newline

## intialize my computer/output  object

$myObj = new-object psobject
add-member -InputObject $myObj -MemberType NoteProperty -Name "Computer" -value $null
add-member -InputObject $myObj -MemberType NoteProperty -Name "DNS Hostname" -value $null
add-member -InputObject $myObj -MemberType NoteProperty -Name "IP Address" -value $null
add-member -InputObject $myObj -MemberType NoteProperty -Name "SCCM" -value $null
add-member -InputObject $myObj -Membertype Noteproperty -name "SCCM Client" -value $null
add-member -InputObject $myobj -MemberType NoteProperty -Name "UserName" -value $null

## bind to SCCM 
Import-Module "C:\Program files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
set-location THC:

# get student and / or admin room DN's
$ouStu = Get-ADOrganizationalUnit -server students.tower -filter '*' -searchbase "OU=OU Classrooms,OU=OU Windows 7,DC=students,DC=tower" | ? { ($_.distinguishedname -like "OU=$($roomin)*") }
# if more than one OU is listed then do something ?
# or use a foreach loop
if ( $ouadm -eq $null) { Write-Output "No Student OU matching OU=$($roomin)$nl"}
else { 
    foreach ( $member in $ouStu) { 
        $objresult = @()
        #  call "call computers in this OU"
                write-output "------------------------------------------------------------------"
        write-output $member.distinguishedname                               
                write-output "------------------------------------------------------------------"
        # and put them all into the output object
        $compObject = get-adcomputer -filter '*' -server "Students.tower" -searchbase $member.distinguishedname -searchscope OneLevel
        foreach ($comp in $compObject) {
            $temp = $myobj | select-object *
            $temp.Computer = $comp.Name
            if ( $comp.DNSHostname -eq $null ) { 
                $temp.'DNS Hostname' = "~~ no DNS hostname ~~"
                $temp.'IP Address' = "{}"  } 
            else { $temp.'DNS Hostname' =  $comp.DNSHostName 
            ## now lookup the IP address
                try {$iparr = [System.Net.Dns]::GetHostAddresses($comp.DNSHostName)
                $temp.'IP Address' = $iparr -like "*.*" }
                catch {$temp.'IP Address' = "{}"}
                    }
            ## finally get the SCCM Object
            try { $sccmobject = get-adcomputer -server Students.tower $comp.Name | get-cmdevice 
                $temp.SCCM = $sccmobject.IsActive
                $temp.'SCCM Client' = $sccmobject.ClientVersion
                $temp.UserName = $sccmobject.UserName }
            catch {
                $temp.SCCM = "{}"
                $temp.'SCCM Client' = {}
                $temp.username = "{}"
                }

            $objresult +=$temp
            }
        $objresult | ft
        }
    }
    
$ouAdm = Get-ADOrganizationalUnit -server admin.tower -filter '*' -searchbase "OU=OU Windows 7,DC=admin,DC=tower" | ? { ($_.distinguishedname -like "OU=$($roomin)*") }
# if more than one OU is listed then do something ?
# or use a foreach loop
if ( $ouadm -eq $null) { Write-Output "No Admin OU matching OU=$($roomin)$nl"}
else { 
    foreach ( $member in $ouAdm) { 
        $objresult = @()
        #  call "call computers in this OU"
                write-output "------------------------------------------------------------------"
        write-output $member.distinguishedname                               
                write-output "------------------------------------------------------------------"
        # and put them all into the output object
        $compObject = get-adcomputer -filter '*' -server "admin.tower" -searchbase $member.distinguishedname -searchscope OneLevel
        foreach ($comp in $compObject) {
            $temp = $myobj | select-object *
            $temp.Computer = $comp.Name
            if ( $comp.DNSHostname -eq $null ) { 
                $temp.'DNS Hostname' = "~~ no DNS hostname ~~"
                $temp.'IP Address' = "{}"  } 
            else { $temp.'DNS Hostname' =  $comp.DNSHostName 
            ## now lookup the IP address
                try {$iparr = [System.Net.Dns]::GetHostAddresses($comp.DNSHostName)
                $temp.'IP Address' = $iparr -like "*.*" }
                catch {$temp.'IP Address' = "{}"}
                    }
            ## finally get the SCCM Object
            try { $sccmobject = get-adcomputer -server admin.tower $comp.Name | get-cmdevice 
                $temp.SCCM = $sccmobject.IsActive
                $temp.'SCCM Client' = $sccmobject.ClientVersion
                $temp.username = $sccmobject.UserName }
            catch {
                $temp.SCCM = "{}"
                $temp.'SCCM Client' = "{}"
                $temp.username = "{}"
                }

            $objresult +=$temp
            }
        $objresult | ft
        }
    }

Pop-Location
