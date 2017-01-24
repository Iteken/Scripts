$a = gwmi win32_networkadapter -filter "PhysicalAdapter = True"
$b = gwmi win32_networkadapterconfiguration | where {$_.description -eq $a.name}
$b.SetTcpipNetbios(2)
