﻿Param(
    $StartOU = 'OU=ViaMonstra,DC=corp,DC=viamonstra,DC=com',
    $SiteServer = $env:COMPUTERNAME,
    $SiteCode = 'THC'
)

$Search = [ADSISearcher]"(|(ObjectClass=organizationalUnit)(ObjectClass=Container))"
$Search.SearchRoot = "LDAP://$StartOU"
$Search.SearchScope = "OneLevel"
$Result = $Search.FindAll()

Function New-CMFolder
{
    Param(
        $SiteCode,
        $SiteServer,
        $ParentFolder,
        $SubFolder
        )
        
        $ParentFolderQuery = Get-WmiObject -Namespace "root\SMS\Site_$($SiteCode)" -Class 'SMS_ObjectContainerNode' -Filter "Name='$ParentFolder'" -ComputerName $SiteServer

        If($ParentFolderQuery.count -eq 0){
            
            $Arguments = @{
                Name = $ParentFolder;
                ObjectType = 5000;
                ParentContainerNodeId = 0
            }
            Set-WmiInstance -Namespace "root\SMS\site_$($SiteCode)" -Class 'SMS_ObjectContainerNode' -Arguments $Arguments -ComputerName $SiteServer

        }
        Else{
            if($ParentFolderQuery.count -ge 2){
                $Number = $ParentFolderQuery.count - 1
                
                $Arguments = @{
                    Name = $SubFolder;
                    ObjectType = 5000;
                    ParentContainerNodeId = $ParentFolderQuery[$Number].ContainerNodeID
                }
                Set-WmiInstance -Namespace "root\SMS\Site_$($SiteCode)" -Class 'SMS_ObjectContainerNode' -Arguments $Arguments -ComputerName $SiteServer
            }
            Else{

                $Arguments = @{
                    Name = $SubFolder;
                    ObjectType = 5000;
                    ParentContainerNodeId = $ParentFolderQuery.ContainerNodeID
                }
                Set-WmiInstance -Namespace "root\SMS\Site_$($SiteCode)" -Class 'SMS_ObjectContainerNode' -Arguments $Arguments -ComputerName $SiteServer
            }
        }
    
}

Function Get-OUChildOUs
{
    PARAM(
         $DN
    )

    $SearchSubOUs = [ADSISearcher]"((ObjectClass=organizationalUnit))"
    $SearchSubOUs.SearchRoot = $DN
    $SearchSubOUs.SearchScope = 'OneLevel'
    $SecondResult = $SearchSubOUs.FindAll()

    
    If($SecondResult.Count -ne 0){
        foreach($item in $SecondResult)
        {
            $Parts = $Item.Properties.distinguishedname -split '(?<![\\]),'              
            New-CMFolder -SiteCode $SiteCode -SiteServer $SiteServer -ParentFolder $(([ADSI]"LDAP://$($parts[1..$($parts.count-1)] -join ',')").Name) -SubFolder $($item.Properties.name)
            Get-OUChildOUs -DN $Item.Path     
        }
    }
}

########## Script Entry Point ################################
New-CMFolder -SiteCode $SiteCode -SiteServer $SiteServer -ParentFolder $(([ADSI]"LDAP://$StartOU").Name)

Foreach($item in $Result)
{
    $Parts = $Item.Properties.distinguishedname -split '(?<![\\]),'
    
    New-CMFolder -SiteCode $SiteCode -SiteServer $SiteServer -ParentFolder $(([ADSI]"LDAP://$($Parts[1..$($Parts.count-1)] -join ',')").Name) -SubFolder $($item.Properties.name)
    Get-OUChildOUs -dn $item.Path

}