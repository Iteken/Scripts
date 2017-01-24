$groups = Get-DistributionGroup
foreach ($g in $groups) {
    $members = (Get-DistributionGroupMember $g.name).count
    write-output "$($g.name),$($g.windowsemailaddress),$($g.managedby),$($members)"
    }