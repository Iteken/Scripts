if ( $pkgs -eq $null ) {$pkgs = get-cmpackage}
if ( $ts -eq $null ) {$ts = get-cmtasksequence} 
# if you are reading this source code
# you are probably fucked.

function Findpkg ($pkgname) { 
	foreach ( $p in $pkgs ) { 
        if ( $p.name -like "*$pkgname*" ) {
            $programs = get-cmprogram -packageID $p.packageID
		    if ($programs.count -gt 2) {
			    foreach ($prog in $programs) {
				    if ($prog.programName -eq "Per-system unattended") { 
					    ## write-output "$($p.packageID) : $($prog.ProgramName) : $($p.name)"
					    return ($p.packageID, $prog.programname, $p.name) }
				    }
			    Write-output "Error: Package $($p.name) has no suitible programs." }
		    else { foreach ($prog in $programs) { return ($p.packageID, $prog.programname, $p.name) }
	        } 
        } 
    }
}

function FindTS ($tsname) { 
	foreach ( $p in $ts ) { 
        if ( $p.name -like "*$tsname*" ) { return ($p.packageID, $p.Name) }
    } 
    write-output "Error: No suitable task sequence found"
}

function finddeployment ($pkgname) {
    Get-CMDeploymentPackage -DistributionPointName plasccm1201.admin.tower -DeploymentPackageName (findpkg $kpgname)[2] 
}



Function Deploypkg ($pkgname, $collection) {
    # deploy a package from a search...   yeah seriously
    # i dont' know why i though this was a good idea but if you are looking at this code
    # you should probably get a lawyer
    $info = findpkg($pkgname)
    $PkgID = $info[0]
    $pkgAction = $info[1]
    write-output "Testing COllection: $($collection)"
    if ( (Get-CMDeviceCollection -name $collection ) -eq $null ) {
            Write-Output "Error: Collection Not Found.  Exiting."
        return} 
    else { Write-output "OK: Ready to create deployment of $($info[2]) to collection '$($collection)'" }
    Start-CMPackageDeployment -CollectionName $collection -DeployPurpose "Required" -PackageID $PkgID -ScheduleEvent "AsSoonAsPossible" -StandardProgram -StandardProgramName $pkgAction
    Write-Output "OK."
}

# function adapted from http://blog.tyang.org/2011/05/20/powershell-script-to-locate-sccm-objects-in-sccm-console/ 
Function Get-ConsolePath ($CentralSiteProvider, $CentralSiteCode, $SCCMObj, $objContainer) 
{ 
    $ContainerNodeID = $SCCMObj.ContainerNodeID 
    $strConsolePath = $null 
    $bIsTopLevel = $false 
    $strConsolePath = $objContainer.Name 
    $ParentContainerID = $objContainer.ParentContainerNodeID 
    if ($ParentContainerID -eq 0) 
    { 
        $bIsTopLevel = $true 
    }  
    else  
    { 
        Do 
        { 
            $objParentContainer = Get-WmiObject -Namespace root\sms\site_$($CentralSiteCode) -Query "Select * from SMS_ObjectContainerNode Where ContainerNodeID = '$ParentContainerID'" -ComputerName $CentralSiteProvider 
            $strParentContainerName = $objParentContainer.Name 
            $strConsolePath = $strParentContainerName + "`\" + $strConsolePath 
            $ParentContainerID = $objParentContainer.ParentContainerNodeID 
            Remove-Variable objParentContainer, strParentContainerName 
            if ($ParentContainerID -eq 0)  
            { 
                $bIsTopLevel = $true 
            } 
             
        } until ($bIsTopLevel -eq $true) 
    } 
    Return $strConsolePath 
} 
 
# get collection name, folder path and device count for a given collection 
Function GetCollectionInfo ($parentName, $site, $coll, $server) 
{ 
    $MembershipQuery = Get-WmiObject -Namespace "root\sms\Site_$($site)" -Query "select collectionid from SMS_CollectionMember_a where collectionid='$($coll.CollectionID)'" -Computername $server
         
    if( $MembershipQuery.Count -ne $null) 
    { 
        $count = $MembershipQuery.Count 
    } 
    else 
    { 
        $count = 1 
    } 
         
    $collInfo = New-Object PSObject -Property @{ 
        CollectionName = $coll.Name 
        Path = $path 
        MemberCount = $count 
    } 
    $collInfo 
} 
 
 
function getCollections ($SiteServer, $siteCode, $ParentFolderName, $recurse = $true) {
##### Entry Point ##### 
 
$collectionArr = @() 
$d = 0 
 
# Get list of all collections on a given SiteServer for the given SiteCode 
$collectionQuery = Get-WmiObject -Namespace "root\sms\Site_$($SiteCode)" -Query "select Name,CollectionID,LastChangeTime,LastMemberChangeTime,LastRefreshTime from SMS_Collection where collectionid like'$($SiteCode)%'" -ComputerName $SiteServer
     
# Loop to process each collection 
foreach ($collection in $collectionQuery) { 
    $d++ 
    Write-Progress -Activity "Processing Collections" -Status "Processed: $($d) of $($collectionQuery.count) " -PercentComplete (($d / $collectionQuery.Count)*100) 
 
    # Get containerItem object for the collection 
    $SCCMObj = Get-WmiObject -Namespace "root\sms\Site_$($SiteCode)" -Query "Select * from SMS_ObjectContainerItem Where InstanceKey = '$($collection.CollectionID)'" -ComputerName $SiteServer 
     
    if($SCCMObj -ne $null) 
    { 
        # Get containerNode object for the collection 
        $objContainer = Get-WmiObject -Namespace "root\sms\Site_$($SiteCode)" -Query "Select * from SMS_ObjectContainerNode Where ContainerNodeID = '$($SCCMObj.ContainerNodeID)'" -ComputerName $SiteServer
         
        if($objContainer -ne $null) 
        { 
            # Get full folder path to collection 
            $path = Get-ConsolePath $SiteServer $SiteCode $SCCMObj $objContainer 
 
            # Recurse flag tells code to display everything in the ParentFolderName folder and below 
            if($Recurse) 
            { 
                # Push collection to the results array if ANY part of the path contains the folder name 
                if($path.contains($ParentFolderName)) 
                { 
                    $collectionArr += GetCollectionInfo $ParentFolderName $SiteCode $collection $SiteServer 
                } 
            } 
            else 
            { 
                # Push collection the results array only if the LAST part of the path is the folder name 
                if($path.EndsWith($ParentFolderName)) 
                { 
                    $collectionArr += GetCollectionInfo $ParentFolderName $SiteCode $collection $SiteServer 
                } 
            } 
        } 
    } 
} 
$collectionArr | Sort-Object -Property "CollectionName"
}

function searchcollections ($target, $siteserver = "plasccm1201", $sitecode = "THC") {
    
    if ($target -eq $null) { Write-Output "Error: Target cannot be null.  Exiting."
        return}

    $collectionQuery = Get-WmiObject -Namespace "root\sms\Site_$($SiteCode)" -Query "select Name,CollectionID from SMS_Collection where collectionid like'$($SiteCode)%'" -ComputerName $SiteServer

    foreach ($coll in $collectionQuery) {
        if ( $coll.name -like "*$($target)*" ) { 
            return ($coll.collectionID,$coll.name) } 
        }
}

