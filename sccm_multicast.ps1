#=========================================================================
# PowerShell Source File -- WDSMulticastMonitor.ps1
#
# AUTHOR: 	Mattias Benninge
# MODIFIED BY:
# COMPANY:
# DATE: 2012-03-26
# VERSION: 01
# SCRIPT LANGUAGE: PowerShell
# LAST UPDATE:
# KEYWORDS: PowerShell, WDS
# DESCRIPTION: Output list of all multicast sessions on a Windows Deployment
#				Server used for multicast by SCCM
#
# KNOWN ISSUES: WDS transport role must be installed on the server so that
#				the COM Object exist.
#
# COMMENT: This script has only been tested on Windows 2008 R2 with Multicast
#			enabled as a SCCM DP Role
#
#=========================================================================

#Create the WDS Com Object
$wdsObject = New-Object -ComObject WdsMgmt.WdsManager
$wdsServer = $wdsObject.GetWdsServer("Localhost")

#Connect to the Transport server
$wdsTrans = $wdsServer.TransportServer

#Retrive all available Namespaces
$wdsNmSpcs = $wdsTrans.NamespaceManager.RetrieveNamespaces("","",$false)

#Create a Hashtable to hold the diffrent streams that the user can choose from
[hashtable]$NSChoice = $null

$Count = $wdsNmSpcs.Count
for ($i=1; $i -lt ($Count + 1); $i++){
    $ns = $wdsNmSpcs.Item($i)
    $ContentsColl = $wdsNmSpcs.Item($i).RetrieveContents()
		#Check for valid streams and add them to $NSChoice
        if ($ContentsColl.Count -ne 0){
        # Assume the $ContentsColl only contains 1 Item when using WDS with SCCM
        $content = $ContentsColl.Item(1)
        $sessioncoll = $content.RetrieveSessions()
        # Assume the $sessioncoll only contains 1 Item when using WDS with SCCM
        $session = $sessioncoll.Item(1)
        $ClientColl = $session.RetrieveClients()

            if ($NSChoice -eq $null)
            {
                $NSChoice = @{"$i" = "$($ns.Name) Clients($($ClientColl.Count))"}
            }
            else
            {
                $NSChoice.Add("$i", "$($ns.Name) Clients($($ClientColl.Count))")
            }
        }
}

#Output all valid streams
$NSChoice.GetEnumerator() | Sort-Object Name

#Prompt for user to select which stream to list clients for
    Do {
        $NSChoiceInput = Read-Host "Select a number to connect to stream or 'q' to quit"
        #Find out if user selected to quit, otherwise answer is an integer
        If ($NSChoiceInput -NotLike "q*") {
            $NSChoiceInput = $NSChoiceInput -as [int]
            }
        }
    #Make sure the choice is valid, if not prompt again until valid or q is entered
    Until ($NSChoice.ContainsKey($NSChoiceInput.ToString()) -OR $NSChoiceInput -Like "q*")
    If ($NSChoiceInput -Like "q*") {
        Break
        } 

	#Create an array to hold all Clients in the stream
   [array]$Clients = $null

   #Create a Hashtable to format the list for Out-Gridview used later
   $CliFormat = @{Label="Master Client";Expression={($_.Id -eq $session.MasterClientId)}},
   @{Label="Name";Expression={$_.Name}},
   @{Label="MacAddress";Expression={$_.MacAddress}},
   @{Label="IpAddress";Expression={$_.IpAddress}},
   @{Label="PercentCompletion";Expression={$_.PercentCompletion}},
   @{Label="JoinDuration";Expression={$_.JoinDuration}},
   @{Label="CpuUtilization";Expression={$_.CpuUtilization}},
   @{Label="MemoryUtilization";Expression={$_.MemoryUtilization}},
   @{Label="NetworkUtilization";Expression={$_.NetworkUtilization}}

   #Connect to the stream choosen by the user
   $ContentsColl = $wdsNmSpcs.Item($NSChoiceInput).RetrieveContents()

        #Make sure the stream is valid and has clients connected
        if ($ContentsColl.Count -ne 0){
        # Assume the $ContentsColl only contains 1 Item when using WDS with SCCM
        $content = $ContentsColl.Item(1)
        $sessioncoll = $content.RetrieveSessions()

        # Assume the $sessioncoll only contains 1 Item when using WDS with SCCM
        $session = $sessioncoll.Item(1)
        $ClientColl = $session.RetrieveClients()

            #Make sure there are clients connected to the stream
            If ($ClientColl.Count -ne 0)
            {
                $Count = $ClientColl.Count
                for ($i=1; $i -lt ($Count + 1); $i++){

                    if ($Clients -eq $null)
                    {
                        $Clients = $ClientColl.Item($i)
                    }
                    else
                    {
                        $Clients = $Clients + $ClientColl.Item($i)
                    }
                }
                # Output the result using a custom formated Out-GridView
                $Clients | Select-Object -property $CliFormat | Out-GridView -Title "WDS Multicast Monitor for SCCM OSD Deployments by Mattias Benninge"
            }
            else
            {
                write-host "This stream doesnt have any clients currently connected"
            }

        }
