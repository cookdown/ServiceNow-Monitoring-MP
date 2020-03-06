#Bring in our parameters
param($instanceURL, $SnowUsername, $SnowPassword)

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
}

Function GetClusterStatusFromServiceNow
{
    param($instanceURL)
    $statsEndpoint = $instanceURL + "api/now/table/sys_cluster_state"
    $results = Invoke-RESTMethod -Uri $statsEndpoint -Headers $headers -Method GET
    $results.result
}

Function CreatePerformancePropertyBags
{
    param($node, $instance)
    $ioStats = [xml]$node.iostats
    $stats = [xml]$node.stats

	$glidePool = $ioStats.xmlstats.iostats.pool | ? {$_.name -eq 'glide'}    

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


try
{
	$oAPI = New-Object -comObject 'MOM.ScriptAPI'
	$oAPI.LogScriptEvent("SNOW Performance", 1050, 4, $("Collecting performance for {0}" -f $InstanceURL))
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = CreateHeaders -username $SnowUsername -password $SnowPassword
    $fetchTime = Measure-Command {$clusterNodes = GetClusterStatusFromServiceNow -instanceURL $instanceURL}

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Connection" -Counter "Fetch Time (MS)" -Instance "Total" -Value $fetchTime.TotalMilliseconds

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
        CreatePerformancePropertyBags -node $snowNode -instance $instance

		# Update the node
		$ioStats = [xml]$snowNode.iostats
		$stats = [xml]$snowNode.stats
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

	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Glide Pool DB" -Counter "Selects" -Instance "Total"  -Value $instanceTotal_select
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Glide Pool DB" -Counter "Selects (Over 1 Second)" -Instance "Total" -Value $instanceTotal_select_onesec
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Glide Pool DB" -Counter "Selects (Over 10 Sec)" -Instance "Total" -Value $instanceTotal_select_tensec
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Glide Pool DB" -Counter "Deletes" -Instance "Total" -Value $instanceTotal_delete
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Glide Pool DB" -Counter "Inserts" -Instance "Total" -Value $instanceTotal_insert
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Glide Pool DB" -Counter "Updates" -Instance "Total" -Value $instanceTotal_update
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Users" -Counter "End Users" -Instance "Total" -Value $instanceTotal_end_user
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Users" -Counter "Logged In" -Instance "Total" -Value $instanceTotal_logged_in
	MakeAddPerfPropertyBag -InstanceUrl $instance -NodeId "NONE" -Object "Users" -Counter "Total" -Instance "Total" -Value $instanceTotal_total

    MakeMonitoringStatusPropertyBag -InstanceUrl -Success $true
}
catch
{
    MakeMonitoringStatusPropertyBag -InstanceUrl -Success $false
}
