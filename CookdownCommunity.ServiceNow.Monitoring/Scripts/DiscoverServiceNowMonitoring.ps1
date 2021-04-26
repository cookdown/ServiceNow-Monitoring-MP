#Bring in our parameters
param($sourceID, $managedEntityID, $location, $instanceUrls, $computerName, $debugDiscovery, $snowUserName, $snowPassword, $proxyUserName, $ProxyPassword, $ProxyURL)

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

Function GetClusterStatusFromServiceNow
{
    param($instanceURL)
    $statsEndpoint = $instanceURL + "api/now/table/sys_cluster_state"
	DebugDiscovery "Querying ServiceNow table for discovery data" $statsEndpoint
    $results = Invoke-RESTMethod @Splat -Uri $statsEndpoint
	DebugDiscovery "Sucessfully queried data from ServiceNow table"
    $results.result
}

Function CreateInstanceObject
{
    param($sourceNode,$sourceURL)

	If ($sourceNode | Get-Member -name 'node_stats') {
        $stats = [xml](Invoke-RestMethod @Splat -Uri $sourceNode.'node_stats'.link).Result.stats
        #If node_stats we're on Paris or later
    }
    Else {
        $stats = [xml]$sourceNode.stats
        #If stats we're on Orlando or earlier
	}

	DebugDiscovery "Parsing XML Response from Server"

    $instance = $discoveryData.CreateClassInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']$")

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/URL" $sourceURL
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/URL$", $sourceURL)

    DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Name" $Stats.xmlstats.instance_name
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Name$", $Stats.xmlstats.instance_name)

	DebugDiscovery "[Name='System!System.Entity']/DisplayName" $Stats.xmlstats.instance_name.ToString()
	$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $Stats.xmlstats.instance_name)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Type" $Stats.xmlstats.instance_type
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Type$", $Stats.xmlstats.instance_type)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Version" $Stats.xmlstats.'glide.build.name'
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Version$", $Stats.xmlstats.'glide.build.name')

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Build" $Stats.xmlstats.'glide.build.tag'
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Build$", $Stats.xmlstats.'glide.build.tag')

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/DatabaseVersion" $stats.xmlstats.'db.product_version'
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/DatabaseVersion$", $stats.xmlstats.'db.product_version')

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Offering" $Stats.xmlstats.'glide.offering'
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Offering$", $Stats.xmlstats.'glide.offering')

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/POPStatus" $stats.xmlstats.'glide.pop3.status'.InnerText
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/POPStatus$", (ArrayToStrings $stats.xmlstats.'glide.pop3.status'.InnerText))

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/SMTPStatus" $stats.xmlstats.'glide.smtp.status'.InnerText
	$instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/SMTPStatus$", (ArrayToStrings $stats.xmlstats.'glide.smtp.status'.InnerText))

	$instance
}

Function CreateNodeObject
{
    param($sourceNode,$sourceURL)

    $node = $discoveryData.CreateClassInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']$")

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/URL" $sourceURL
	$node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/URL$", $sourceURL)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/NodeId" $sourceNode.node_id
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/NodeId$", $sourceNode.node_id)

    DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/SystemId" $sourceNode.system_id
	$node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/SystemId$", $sourceNode.system_id)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/CreatedOn" $sourceNode.sys_created_on
	$node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/CreatedOn$", $sourceNode.sys_created_on)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/AllowInbound" $sourceNode.allow_inbound
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/AllowInbound$", $sourceNode.allow_inbound)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/ReadyToFailover" $sourceNode.ready_to_failover
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/ReadyToFailover$", $sourceNode.ready_to_failover)

	DebugDiscovery "[Name='System!System.Entity']/DisplayName" $sourceNode.system_id
	$node.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $sourceNode.system_id)
    $node
}

Function CreateWatcherNode
{
    param($computerName,$sourceURL)

    $watcherNode = $discoveryData.CreateClassInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']$")

	DebugDiscovery "[Name='Windows!Microsoft.Windows.Computer']/PrincipalName" $computerName
	$watcherNode.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/Instance" $sourceURL
    $watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/Instance$", $sourceURL)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/InstanceUrlBase" $sourceURL.Replace("https://","").Replace("/","")
	$watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/InstanceUrlBase$", $sourceURL.Replace("https://","").Replace("/",""))

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/Location$" $location
	$watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/Location$", $location)

	DebugDiscovery "[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/ProxyURL$" $ProxyURL
	$watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/ProxyURL$", $ProxyURL)

	DebugDiscovery "[Name='System!System.Entity']/DisplayName" $location
	$watcherNode.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $location)
    $watcherNode
}

Function CreateWatcherRelationship
{
	param($instanceObject,$watcherObject)
    $watcherRelationship = $discoveryData.CreateRelationshipInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.InstanceContainsWatchers']$")
    $watcherRelationship.Source = $instanceObject
    $watcherRelationship.Target = $watcherObject
    $watcherRelationship
}

Function DebugDiscovery
{
	param($messageString,$objectValue = $null)

	#We'll only write out data if we have debug enabled, otherwise, skip it
	if($debugDiscovery)
	{
		if($null -ne $objectValue)
        {
            $api.LogScriptEvent("SNOW Discovery", 1020, 4, "Discovery DEBUG:`n$messageString`nWith a value of: $objectValue")
        }
        else
        {
            $api.LogScriptEvent("SNOW Discovery", 1020, 4, "Discovery DEBUG:`n$messageString")
        }

	}
}

Function ArrayToStrings
{
	param($sourceObject)
	[string]$cleanResult = "";

	foreach ($stringLine in $sourceObject)
	{
		$cleanResult = $cleanResult + $stringLine.ToString();
		$cleanResult = $cleanResult + [System.Environment]::NewLine;
	}

    $cleanResult
}


#Initialize the Object and create a discovery data unique to this Agent
$api = New-Object -comObject 'MOM.ScriptAPI'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$debugDiscovery = [bool]::Parse($debugDiscovery.ToString())

$discoveryData = $api.CreateDiscoveryData(0, $sourceID, $managedEntityID)

debugdiscovery "SNow Discovery running under $(whoami)"

[string]$ActiveInstance = "Not started";

$Splat = @{
	Headers = (CreateHeaders -username $snowUserName -password $snowPassword)
	Method = 'Get'
	ErrorAction = 'Stop'
}

If ($debugDiscovery) {
	$Splat.add('Verbose',$True)
}

If ($ProxyURL) {
	$Splat.add('proxy',$ProxyURL)
	DebugDiscovery "Using a proxy" $ProxyURL

	If ((-not [string]::IsNullOrWhiteSpace($proxyUserName)) -and (-not ([string]::IsNullOrWhiteSpace($ProxyPassword)))) {
		$Splat.add('ProxyCredential',([pscredential]::new($ProxyUsername,($ProxyPassword | ConvertTo-SecureString -AsPlainText -Force))))
		DebugDiscovery "Using proxy credentials"
	}
}
#Create a splat to use with our calls to SNOW

try
{
    foreach($instance in $instanceUrls.Trim().Split(","))
    {
	    $api.LogScriptEvent("SNOW Discovery", 1013, 4, $("working on cluster {0}." -f $instance))
	    $instance = $instance.Trim().ToLower()
		$ActiveInstance = $instance;
        $clusterNodes = GetClusterStatusFromServiceNow -instanceURL $instance
	    DebugDiscovery "retrieved cluster nodes count = $($clusterNodes.count)"

        # Discover instance
		DebugDiscovery "Creating object for ServiceNow Instance" $instance
        $serviceNowInstance = CreateInstanceObject -sourceNode $clusterNodes[0] -sourceURL $instance
		DebugDiscovery "Adding Instance Object to Discovery Payload"
        $discoveryData.AddInstance($serviceNowInstance)

        #Add watcher
		DebugDiscovery "Creating object for Watcher Node" $computerName
        $watcherNode = CreateWatcherNode -computerName $computerName -sourceURL $instance
		DebugDiscovery "Adding Watcher Node Object to Disovery Payload"
        $discoveryData.AddInstance($watcherNode)

        #Relate watcher to instance
		DebugDiscovery "Creating Relationship between Instance and Watcher Node"
        $watcherRelationship = CreateWatcherRelationship -instanceObject $serviceNowInstance -watcherObject $watcherNode
		DebugDiscovery "Adding Relationship to Payload"
        $discoveryData.AddInstance($watcherRelationship)

        #Add Nodes
        foreach($snowNode in $clusterNodes)
        {
			DebugDiscovery "Creating object for ServiceNow Node" $snowNode.node_id
            $node = CreateNodeObject -sourceNode $snowNode -sourceURL $instance
			DebugDiscovery "Adding ServiceNow Node object to Paload" $snowNode.node_id
            $discoveryData.AddInstance($node)
        }
    }

    $api.LogScriptEvent("Cookdown SNOW Discovery", 1012, 0, $("Discovery Completed sucessfully"))
    $discoveryData
}
catch
{
    $api.LogScriptEvent("Cookdown SNOW Discovery", 1015, 1, $("Discovery Failed with error $($_.Exception.Message)`n`nDiscovery was trying to process $ActiveInstance"))
}
