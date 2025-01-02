# -----| lab-RandomScan.ps1 |------ #
# Author: Dave Chambers
# Last updated:	12/5/2024
# Tested using:	PowerShell v7.4.6
# ------------------------------------ #

<#
.SYNOPSIS
This script will send a specified number of random backups to the NetBackup mmalware scanner

.DESCRIPTION
This script creates a scan request with provided parameters. The primary server, scan count, scan pool name, and API key are mandatory.
Tested using NetBackup 10.5 and PowerShell 7.4.6.  This is a DEMO script - it should NOT be used in PRODUCTION without modification.

.PARAMETER primaryServer
This is the FQDN of your NetBackup primary server.
.PARAMETER scanCount
This is the number of backup IDs to be sent to the malware scanner for scanning.
.PARAMETER poolName
This is the scan pool name
.PARAMETER apiKey
This is the API key being used to authorize the endpoint request.

.EXAMPLE
./random-Scan.ps1 -primaryServer nbuprimary.lab.local -scanCount 5 -poolName scan-pool -apiKey <api key>
#>

Param (
	[Parameter(Mandatory)][string]$primaryServer,
	[Parameter(Mandatory)][int]$scanCount,
	[Parameter(Mandatory)][string]$poolName,
	[Parameter(Mandatory)][string]$apiKey
)

# API variables
$header = [ordered]@{ Authorization = $apiKey }
$content = "application/vnd.netbackup+json;version=11.0"
$baseUri = "https://" + $primaryServer + "/netbackup/"

# Variables to get images from today
$today = get-date -UFormat %Y-%m-%d
$imagesUri = "catalog/images?"
$filtersUri = "filter=backupTime ge " + $today + "T00:00:00Z"
$limitsUri = "&page%5Blimit%5D=100&page%5Boffset%5D=0"

# Get the images and add them to an array
$uri = $baseUri + $imagesUri + $filtersUri + $limitsUri
$response = Invoke-WebRequest -Method GET -Uri $uri -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
$images = (ConvertFrom-Json -InputObject $response)
$imagesList = @()
$imagesList = ($images | Select-Object -Expand data | Select-Object @{n='backupId'; e={$_.id}}, @{n='copyNumber'; e={$_.attributes.fragments[0].copyNumber}}, @{n='backupTime'; e={$_.attributes.backupTime}}, @{n='policyName'; e={$_.attributes.policyName}})
$imagesCount = $images.data.count
Write-Host "Found $imagesCount backup images from $today"

# Just in case there are very few backup images from today
if($scanCount -gt $imagesCount) {$scanCount = $imagesCount} 

# Get the scanHostPool id
$poolsUri = "malware/scan-host-pools"
$content = "application/vnd.netbackup+json;version=12.0"
$uri = $baseUri + $poolsUri
$response = Invoke-WebRequest -Method GET -Uri $uri -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
$pools = (ConvertFrom-Json -InputObject $response)
$count = $pools.data.count
for($i = 0; $i -lt $count ; $i++){
	if ($pools.data.attributes.poolName -eq $poolName) {$poolId = $pools.data.id}
}
Write-Host "The malware scanner host pool ID for $poolName is $poolId`n"	

# Select images randomly, send them to malware scanner
$content = "application/vnd.netbackup+json;version=12.0"
$scanUri = "malware/on-demand-scan"
$uri = $baseUri + $scanUri
$sent = 0
$maxIndex = $imagesCount - 1
for ($i = 0; $i -lt $scanCount; $i++){
	$randomIndex = Get-SecureRandom -Maximum $maxIndex
	$scanId = $imagesList[$randomIndex].backupId
	Write-Host "Malware scan" ($i+1) "backupId = $scanId"
	
	#Send the scanId to the malware scan API
	$data = @{
		type = "onDemandScanRequest"
		attributes = @{
			backupIds = @(
				@{
					backupId = $scanId
					copyNumber = $imagesList[$randomIndex].copyNumber
				}
			)
			scanHostPool = $poolId
		}
	}
	$body = @{data=$data} | ConvertTo-Json -Depth 10
	$response = Invoke-WebRequest -Method POST -Uri $uri -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
	
	# Output scan success or failure
	$scanResponse = (ConvertFrom-Json -InputObject $response)
	$scanResponse.data.attributes.msg
	$status = $scanResponse.data.attributes.status
	if($status -eq 'SUCCESS'){$sent++}
	
	#Remove the backup image that has been scanned from the array to prevent repeat scans
	$imagesList = $imagesList | Where-Object { $_.backupId -ne $scanId }
	$arrayContents = "The image list array has " + $imagesList.count + " backup images remaining.`n"
	$maxIndex = $imagesList.count - 1
	Write-Host $arrayContents
	
	# Pause before sending next backup image to scanner
	Start-Sleep -Seconds 5
}
Write-Host "NetBackup sent" $sent "backup images to the malware scanner"
#End script
