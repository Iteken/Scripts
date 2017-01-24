function GetODUsage($url)
{
    if ($exists = (Get-SPosite $url -ErrorAction SilentlyContinue) -ne $null)  {
        $sc = Get-SPOSite $url -Detailed -erroraction stop | select url, storageusagecurrent, Owner
        if ($sc.storageusagecurrent -gt 2) {write-output "$($sc.owner), $($sc.storageusagecurrent) kb Used."}
        }
}
foreach($usr in $(Get-MsolUser -All -domainname "staff.tower.ac.uk"))
{
    if ($usr.IsLicensed -eq $true)
    {
        $upn = $usr.UserPrincipalName.Replace(".","_")
        $od4bSC = "https://livetowerac-my.sharepoint.com/personal/$($upn.Replace("@","_"))"
#        $od4bSC
        foreach($lic in $usr.licenses){
        
            if ($lic.AccountSkuID -eq "livetowerac:STANDARDWOFFPACK_IW_FACULTY") {GetODUsage($od4bSC)}
            elseif ($lic.AccountSkuID -eq "livetowerac:STANDARDWOFFPACK_FACULTY") {GetODUsage($od4bSC) }    
        }
    }
}


get-sposite 