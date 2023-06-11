<#
.SYNOPSIS
This script creates the initial training data for an anomaly test.
It then performs a set number of backups using the NetBackup API for a baseline of activity.

.DESCRIPTION
This script can be run using NetBackup 10.2 and higher.
The policy name - win-4hr
The schedule name - win-4hr-full
The client name - console.lab.local

.EXAMPLE
./preAnomalyBackups.ps1 -PrimaryServer <primaryServer> -ApiKey <api key>
#>

# Written by Dave Chambers
# Last updated 6/11/2023
# Tested with PowerShell Version 7.3.4

Param (
    [string]$PrimaryServer = $(Throw "Please specify the name of the NetBackup primary server using the -PrimaryServer parameter."),
	[string]$ApiKey = $(Throw "Please include the API key using the -ApiKey parameter.")
)

# Current path
$location = Get-Location
# Initial directories
$pathNames = @('Engineering', 'Operations', 'Security', 'HR', 'Sales')
# Set size of each randomized file - 10KB = 10240 1MB = 1048576 5MB = 5242880 10MB = 10485760 1GB = 1073741824
$fileSize = 10240

# Common variables for API calls, these don't change for each call
$Header = [ordered]@{ Authorization = $ApiKey }
$Content = "application/vnd.netbackup+json;version=9.0"
# Body variable for manual-backup
$Body = @{
	data = @{
		type = 'backupRequest'
		attributes = @{
			policyName = 'win-4hr'
			scheduleName = 'win-4hr-full'
			clientName = 'console.lab.local'
			trialBackup = $false
		}
	}
}
$JsonBody = ($Body | ConvertTo-Json -Depth 10) # This converts the Body variable into JSON format

# Backup and incrementally add files
$backupCount = 31
for ($i=1; $i -le $backupCount; $i++){
	# Determine how many files to incrementally create -- 3% change rate
	$pathItems = Get-ChildItem $location.path -Recurse | measure | %{$_.count}
	$incremental = [Math]::Floor($pathItems * 0.03)
	
	# Start a manual backup using API
	$url = "https://" + $PrimaryServer + "/netbackup/admin/manual-backup"
		$Response = Invoke-RestMethod -Method POST -Uri $Url -Body $JsonBody -ContentType $Content -Headers $Header -SkipCertificateCheck
	$jobId = $Response.data.attributes.jobId
	Write-Host "Backup $i of $backupCount started, the JobID is $JobId"
	# Delay 10 seconds to let the job start
	Start-Sleep -Seconds 10 
	
	# Get the status of the backup job using API
	$url = "https://" + $PrimaryServer + "/netbackup/admin/jobs/" + $jobId
	$Response = Invoke-RestMethod -Method GET -Uri $Url -ContentType $Content -Headers $Header -SkipCertificateCheck
	$state = $Response.data.attributes.state
	# Pause if a backup job is acitve or queued
	while ($state -eq 'ACTIVE' -or $state -eq 'QUEUED'){
		Start-Sleep -Seconds 3
		$Response = Invoke-RestMethod -Method GET -Uri $Url -ContentType $Content -Headers $Header -SkipCertificateCheck
		$state = $Response.data.attributes.state
	}
	
	# Add some files
	$j = $i % 5
	$targetPath = $pathNames[$j]
	$newPath = $location.path + '\' + $targetPath + '\'
	# Create files       
	for ($k=1; $k -le $incremental; $k++)
		{
			$out = new-object byte[] $fileSize; (new-object Random).NextBytes($out);
			$m = Get-Random
			[IO.File]::WriteAllBytes($newPath + "file_$m.txt", $out)			
		}
	Write-Host "Backup complete, added $incremental files to $newPath to simulate 3% change rate"
}
# End of script
