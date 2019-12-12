#Bring in our parameters
param($sourceID, $managedEntityID, $location, $instanceUrls, $computerName, $snowUserName, $snowPassword)

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
    $results = Invoke-RESTMethod -Uri $statsEndpoint -Headers $headers -Method GET -ErrorAction Stop
    $results.result
}

Function CreateInstanceObject
{
    param($sourceNode,$sourceURL)

    $stats = [xml]$sourceNode.stats
    $instance = $discoveryData.CreateClassInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']$")
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/URL$", $sourceURL)
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Name$", $Stats.xmlstats.instance_name)
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Type$", $Stats.xmlstats.instance_type)
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Version$", $Stats.xmlstats.'glide.build.name')
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Build$", $Stats.xmlstats.'glide.build.tag')
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/DatabaseVersion$", $stats.xmlstats.'db.product_version')
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/Offering$", $Stats.xmlstats.'glide.offering')
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/POPStatus$", $stats.xmlstats.'glide.pop3.status'.InnerText)
    $instance.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/SMTPStatus$", $stats.xmlstats.'glide.smtp.status'.InnerText)
	$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $Stats.xmlstats.instance_name)
    $instance
}

Function CreateNodeObject
{
    param($sourceNode,$sourceURL)

    $stats = [xml]$sourceNode.stats
    $node = $discoveryData.CreateClassInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']$")
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowInstance']/URL$", $sourceURL)
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/NodeId$", $sourceNode.node_id)
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/SystemId$", $sourceNode.system_id)
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/CreatedOn$", $sourceNode.sys_created_on)
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/AllowInbound$", $sourceNode.allow_inbound)
    $node.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.ServiceNowNode']/ReadyToFailover$", $sourceNode.ready_to_failover)
	$node.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $sourceNode.system_id)
    $node
}

Function CreateWatcherNode
{
    param($computerName,$sourceURL)
    $watcherNode = $discoveryData.CreateClassInstance("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']$")
    $watcherNode.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
    $watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/Instance$", $sourceURL)
	$watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/InstanceUrlBase$", $sourceURL.Replace("https://","").Replace("/",""))
    $watcherNode.AddProperty("$MPElement[Name='CookdownCommunity.ServiceNow.Monitoring.WatcherNode']/Location$", $location)
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

#Initialize the Object and create a discovery data unique to this Agent
$api = New-Object -comObject 'MOM.ScriptAPI'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$discoveryData = $api.CreateDiscoveryData(0, $sourceID, $managedEntityID)
$headers = CreateHeaders -username $snowUserName -password $snowPassword

try
{
    foreach($instance in $instanceUrls.Trim().Split(","))
    {
	    $api.LogScriptEvent("SNOW Discovery", 1033, 4, $("working on cluster {0}." -f $instance))    
	    $instance = $instance.Trim().ToLower()
        $clusterNodes = GetClusterStatusFromServiceNow -instanceURL $instance
	    $api.LogScriptEvent("SNOW Discovery", 1033, 4, $("retrieved cluster nodes count = {0}" -f $clusterNodes.count))    
        # Discover instance
        $serviceNowInstance = CreateInstanceObject -sourceNode $clusterNodes[0] -sourceURL $instance
        $discoveryData.AddInstance($serviceNowInstance)
	
        #Add watcher
        $watcherNode = CreateWatcherNode -computerName $computerName -sourceURL $instance
        $discoveryData.AddInstance($watcherNode)
	
        #Relate watcher to instance
        $watcherRelationship = CreateWatcherRelationship -instanceObject $serviceNowInstance -watcherObject $watcherNode
        $discoveryData.AddInstance($watcherRelationship)
	
        #Add Nodes
        foreach($snowNode in $clusterNodes)
        {
            $node = CreateNodeObject -sourceNode $snowNode -sourceURL $instance
            $discoveryData.AddInstance($node)
		    $api.LogScriptEvent("SNOW Discovery", 1011, 0, $("Created node {0}" -f $snowNode.system_id))
        }
    }

    $api.LogScriptEvent("Cookdown SNOW Discovery", 1012, 0, $("Discovery Completed sucessfully"))
    $discoveryData
}
catch
{
    $api.LogScriptEvent("Cookdown SNOW Discovery", 1015, 1, $("Discovery Failed with error $($_.Exception.Message)"))
}