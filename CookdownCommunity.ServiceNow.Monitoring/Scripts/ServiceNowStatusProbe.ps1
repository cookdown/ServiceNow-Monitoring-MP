#Bring in our parameters
param($instanceURL, $SnowUsername, $SnowPassword, $debugProbe, $proxyUserName, $ProxyPassword)

Function CreateHeaders
{
	param($username, $password)
	# Build auth header
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))

	# Set proper headers
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
	$headers.Add('Accept','application/json')
	$headers
}

Function MakeAddPerfPropertyBag
{
  param(
    [string] $InstanceURL,
    [string] $NodeId,
    [string] $Object = "",
    [string] $Instance = "",
    [string] $Counter = "",
    [double] $Value = $null
    )

  if ($Value -ne $null)
  {
    if ($Value -ne '')
       {
		  $perfBag = $oAPI.CreatePropertyBag()
		  $perfBag.AddValue("Type","Performance")
		  $perfBag.AddValue("InstanceURL",$InstanceURL)
		  $perfBag.AddValue("NodeId",$NodeId)
		  $perfBag.AddValue("Object",$Object)
		  $perfBag.AddValue("Instance",$Instance)
		  $perfBag.AddValue("Counter",$Counter)
		  $perfBag.AddValue("Value",$Value)
		  $perfBag

		  $debugString = "InstanceURL: $InstanceURL`nNodeId: $NodeId`nObject: $Object`nInstance: $Instance`nCounter: $Counter`nValue: $Value"
		  DebugProbe "Creating performance property bag" $debugString
       }
  }
}

Function MakeMonitoringStatusPropertyBag
{
	param(
		[string] $InstanceURL,
		[bool] $Success
	)

		$perfBag = $oAPI.CreatePropertyBag()
		$perfBag.AddValue("Type","Monitoring")
		$perfBag.AddValue("InstanceURL",$InstanceURL)
		$perfBag.AddValue("Success",$Success.ToString())
		$perfBag

		$debugString = "InstanceURL: $InstanceURL`nSuccess: $Success"
		DebugProbe "Creating status property bag" $debugString
}

Function GetClusterStatusFromServiceNow
{
    param($instanceURL)
    $statsEndpoint = $instanceURL + "api/now/table/sys_cluster_state"
    $results = Invoke-RESTMethod @splat -Uri $statsEndpoint
    $results.result
}

Function CreatePerformancePropertyBags
{
    param($node, $instance, $ioStats, $stats)

	$glidePool = $ioStats.xmlstats.iostats.pool | Where-Object {$_.name -eq 'glide'}

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Memory" -Counter "Total" -Instance $node.system_id -Value $stats.xmlstats.'system.memory.total'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Memory" -Counter "In Use" -Instance $node.system_id -Value $stats.xmlstats.'system.memory.in.use'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Memory" -Counter "Percent Free" -Instance $node.system_id -Value $stats.xmlstats.'system.memory.pct.free'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Memory" -Counter "Max" -Instance $node.system_id -Value $stats.xmlstats.'system.memory.max'.InnerText

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Cache Flushes" -Instance $node.system_id -Value $stats.xmlstats.'servlet.cache.flushes'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Uptime" -Instance $node.system_id -Value $stats.xmlstats.'servlet.uptime'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Transactions" -Instance $node.system_id -Value $stats.xmlstats.'servlet.transactions'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Errors Handled" -Instance $node.system_id -Value $stats.xmlstats.'servlet.errors.handled'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Processor Transactions" -Instance $node.system_id -Value $stats.xmlstats.'servlet.processor.transactions'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Cancelled Transactions" -Instance $node.system_id -Value $stats.xmlstats.'servlet.cancelled.transactions'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Servlet" -Counter "Active Sessions" -Instance $node.system_id -Value $stats.xmlstats.'servlet.active.sessions'

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Scheduler" -Counter "Worker Count" -Instance $node.system_id -Value $stats.xmlstats.'scheduler.worker.count'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Scheduler" -Counter "Queue Length" -Instance $node.system_id -Value $stats.xmlstats.'scheduler.queue.length'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Scheduler" -Counter "Mean Queue Age" -Instance $node.system_id -Value $stats.xmlstats.'scheduler.mean.queue.age'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Scheduler" -Counter "Total Jobs" -Instance $node.system_id -Value $stats.xmlstats.'scheduler.total.jobs'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Scheduler" -Counter "Total Burst Workers" -Instance $node.system_id -Value $stats.xmlstats.'scheduler.total.burst.workers'

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Glide Pool DB" -Counter "Selects" -Instance $node.system_id -Value $glidePool.select
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Glide Pool DB" -Counter "Selects (Over 1 Second)" -Instance $node.system_id -Value $glidePool.select_onesec
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Glide Pool DB" -Counter "Selects (Over 10 Sec)" -Instance $node.system_id -Value $glidePool.select_tensec
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Glide Pool DB" -Counter "Deletes" -Instance $node.system_id -Value $glidePool.delete
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Glide Pool DB" -Counter "Inserts" -Instance $node.system_id -Value $glidePool.insert
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Glide Pool DB" -Counter "Updates" -Instance $node.system_id -Value $glidePool.update

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "JVM" -Counter "Classes Loaded" -Instance $node.system_id -Value $stats.xmlstats.'jvm.classes.loaded'
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "JVM" -Counter "Classes Unloaded" -Instance $node.system_id -Value $stats.xmlstats.'jvm.classes.unloaded'

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Users" -Counter "End Users" -Instance $node.system_id -Value $stats.xmlstats.sessionsummary.end_user
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Users" -Counter "Logged In" -Instance $node.system_id -Value $stats.xmlstats.sessionsummary.logged_in
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId $node.node_id -Object "Users" -Counter "Total" -Instance $node.system_id -Value $stats.xmlstats.sessionsummary.total
}

Function DebugProbe
{
	param($messageString,$objectValue = $null)

	#We'll only write out data if we have debug enabled, otherwise, skip it
	if($debugProbe)
	{
		if($null -ne $objectValue)
        {
            $oAPI.LogScriptEvent("SNOW Status", 1070, 4, "Status Probe DEBUG:`n$messageString`nWith a value of: $objectValue")
        }
        else
        {
            $oAPI.LogScriptEvent("SNOW Status", 1070, 4, "Status Probe DEBUG:`n$messageString")
        }

	}
}

# Create the API object and then we'll start our performance collection
$oAPI = New-Object -comObject 'MOM.ScriptAPI'

try
{
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	$debugProbe = [bool]::Parse($debugProbe.ToString())

	DebugProbe "SNow Status Probe running under $(whoami)"

	$RegPath = 'SOFTWARE\CookdownManagementPacks\SNOWMonitoring'

	Try {
		$KeyProperties = Get-ItemProperty "HKLM:\$RegPath" -ErrorAction Stop
	}
	Catch {
		$KeyProperties = Get-ItemProperty "HKCU:\$RegPath" -ErrorAction Continue
	}

	If ($KeyProperties.DebugProbe) {
		$debugProbe = $True
		DebugProbe 'DebugProbe set to true via registry'
		DebugProbe 'Registry Key Properties' $($KeyProperties | Out-String)
	}

	$Splat = @{
		Headers = (CreateHeaders -username $snowUserName -password $snowPassword)
		Method = 'Get'
		ErrorAction = 'Stop'
	}

	If ($debugProbe) {
		$Splat.add('Verbose',$True)
	}

	If ($KeyProperties.ProxyURL) {
		$Splat.add('proxy',$KeyProperties.ProxyURL)
		DebugProbe "Using Proxy" $KeyProperties.ProxyURL

		If ((-not [string]::IsNullOrWhiteSpace($proxyUserName)) -and (-not ([string]::IsNullOrWhiteSpace($ProxyPassword)))) {
			$Splat.add('ProxyCredential',([pscredential]::new($ProxyUsername,($ProxyPassword | ConvertTo-SecureString -AsPlainText -Force))))
			DebugProbe "Using proxy credentials"
		}
	}
	#Create a splat to use with our calls to SNOW

	DebugProbe "Creating performance property bag"

	DebugProbe "Connecting to ServiceNow Instance to pull Performance and Status" $instanceURL
	$fetchTime = Measure-Command {$clusterNodes = GetClusterStatusFromServiceNow -instanceURL $instanceURL}

	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Connection" -Counter "Fetch Time (MS)" -Instance "Total" -Value $fetchTime.TotalMilliseconds

	# Setup our roll-up Performance
	$instanceTotal_select = 0
	$instanceTotal_select_onesec = 0
	$instanceTotal_select_tensec = 0
	$instanceTotal_delete = 0
	$instanceTotal_insert = 0
	$instanceTotal_update = 0
	$instanceTotal_end_user = 0
	$instanceTotal_logged_in = 0
	$instanceTotal_total = 0

    foreach($snowNode in $clusterNodes)
    {

		DebugProbe "Getting performance data for a cluster node" $snowNode.node_id

		#Get Stats
		If ($snowNode | Get-Member -name 'node_stats') {
			$NodeStats = (Invoke-RestMethod @Splat -Uri $snowNode.'node_stats'.link).Result
			$ioStats = [xml]$NodeStats.iostats
			$stats = [xml]$NodeStats.stats
			#If node_stats we're on Paris or later
		}
		Else {
			$ioStats = [xml]$snowNode.iostats
			$stats = [xml]$snowNode.stats
			#If stats we're on Orlando or earlier
		}

		DebugProbe "Parsing performance data for a cluster node" $snowNode.node_id

        CreatePerformancePropertyBags -node $snowNode -instance $instance -ioStats $ioStats -stats $stats

		# Update the node
		$glidePoolData = $ioStats.xmlstats.iostats.pool | ? {$_.name -eq 'glide'}
		$instanceTotal_select = $instanceTotal_select + $glidePoolData.select
		$instanceTotal_select_onesec = $instanceTotal_select_onesec + $glidePoolData.select_onesec
		$instanceTotal_select_tensec = $instanceTotal_select_tensec + $glidePoolData.select_tensec
		$instanceTotal_delete = $instanceTotal_delete + $glidePoolData.delete
		$instanceTotal_insert = $instanceTotal_insert + $glidePoolData.insert
		$instanceTotal_update = $instanceTotal_update + $glidePoolData.update
		$instanceTotal_end_user = $instanceTotal_end_user + $stats.xmlstats.sessionsummary.end_user
		$instanceTotal_logged_in = $instanceTotal_logged_in + $stats.xmlstats.sessionsummary.logged_in
		$instanceTotal_total = $instanceTotal_total + $stats.xmlstats.sessionsummary.total
    }

	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Glide Pool DB" -Counter "Selects" -Instance "Total"  -Value $instanceTotal_select
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Glide Pool DB" -Counter "Selects (Over 1 Second)" -Instance "Total" -Value $instanceTotal_select_onesec
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Glide Pool DB" -Counter "Selects (Over 10 Sec)" -Instance "Total" -Value $instanceTotal_select_tensec
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Glide Pool DB" -Counter "Deletes" -Instance "Total" -Value $instanceTotal_delete
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Glide Pool DB" -Counter "Inserts" -Instance "Total" -Value $instanceTotal_insert
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Glide Pool DB" -Counter "Updates" -Instance "Total" -Value $instanceTotal_update
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Users" -Counter "End Users" -Instance "Total" -Value $instanceTotal_end_user
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Users" -Counter "Logged In" -Instance "Total" -Value $instanceTotal_logged_in
	MakeAddPerfPropertyBag -InstanceUrl $instanceURL -NodeId "NONE" -Object "Users" -Counter "Total" -Instance "Total" -Value $instanceTotal_total

    MakeMonitoringStatusPropertyBag -InstanceUrl $instanceURL -Success $true
	$oAPI.LogScriptEvent("SNOW Performance", 1052, 4, $("Performance for {0} collected successfully" -f $InstanceURL))
}
catch
{
    MakeMonitoringStatusPropertyBag -InstanceUrl $instanceURL -Success $false
	$oAPI.LogScriptEvent("SNOW Performance", 1055, 1, $("Performance for {0} could not be collected.`n`nError Message:`n{1}" -f $InstanceURL, $_))
}
