$coll = get-cmdevicecollection
foreach ($c in $coll) {
	write-output "$($c.name) : $($c.collectionid)"
	$deps = get-cmdeployment -collectionname $c.name
	foreach ($d in $deps) {
		write-output "$($d.SoftwareName)"
	}
	Write-Output "---------------------------"
}