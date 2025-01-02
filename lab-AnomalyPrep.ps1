# -----| lab-AnomalyPrep.ps1 |------ #
# Author: Dave Chambers
# Last updated:	5/7/2023
# Tested using:	PowerShell v7.4.2
# -------------------------------------- #

# This script creates the initial training data for an anomaly test. It creates 10 directories with 201 files in each.
# It then performs a set number of backups using the NetBackup API for a baseline of activity.
# The goal with the incremental growth is to simulate user activity

Param (
	[string]$primaryServer = 'nbuprimary.lab.local',
	[string]$policyName = 'win-4hr',
	[string]$policyType = 'MS-Windows',
	[string]$storage = 'MSDPSTU',
	[string]$clientName = 'console.lab.local',
	[string]$backupSelection = 'C:\Utils',
	[string]$scheduleName = 'win-4hr-full',
	[Parameter(Mandatory)] [string]$apiKey
)

# ----- API variables ------------------------------------------- #
$header = [ordered]@{ Authorization = $apiKey }
$content = "application/vnd.netbackup+json;version=9.0"
$baseUri = "https://" + $primaryServer + "/netbackup/"
$policiesUri = "config/policies/"
$hardwareUri = "wui/clients/" + $clientName + "/hardware-os-info"
$backupUri = "admin/manual-backup"
$jobsUri = "admin/jobs/"
# ----- End API variables --------------------------------------- #
   
# ----- Create initial test directories and dummy files ----- #
# Current path
$location = Get-Location
# Initial directories
$pathNames = @('Engineering', 'Finance', 'HR', 'Infrastructure', 'IT', 'Legal', 'Marketing', 'Operations', 'Sales', 'Veritas')
# Set size of each randomized file - 10KB = 10240 1MB = 1048576 5MB = 5242880 10MB = 10485760 1GB = 1073741824
$fileSize = 10240
# Number of files to create
$fileCount = 201

for ($d=0; $d -lt $pathNames.count; $d++){
	New-Item -Path $location.path -Name $pathNames[$d] -ItemType 'directory'
	$newPath = $location.path + '\' + $pathNames[$d] + '\'
	# Create files in each directory        
	for ($i=1; $i -le $fileCount; $i++)
		{
			$out = new-object byte[] $fileSize; (new-object Random).NextBytes($out);
			$m = Get-Random
			[IO.File]::WriteAllBytes($newPath + "file$m.txt", $out)
		}
}
# ----- End create directories ------------------------------ #


# ---------- Start AddPolicy Definition ---------------------------------------------------------------------------------------------------------- #
Function AddPolicy()
{
	# Create the policy
	$data = @{
		type="policy"
		id=$policyName
		attributes=@{
			policy=@{
				policyName=$policyName
				policyType=$policyType
				policyAttributes=@{
					storage = "MSDPSTU"
					useAccelerator = $true
					useMultipleDataStreams = $true
				}
				clients=@()
				schedules=@()
				backupSelections=@{selections=@()}
			}
		}
	}
	$body = @{data=$data} | ConvertTo-Json -Depth 10
	$uri = $baseUri + $policiesUri
	Write-Host "`nSending a request to create $PolicyName."
	$response = Invoke-WebRequest -Method POST -Uri $uri -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing		
	if ($response.StatusCode -ne 204){
		throw "Unable to create policy $policyName."
	}
	Write-Host "$policyName created successfully."
}
# ---------- End AddPolicy Definition ------------------------------------------------------------------------------------------------------------ #

# ---------- Start AddClient Definition ---------------------------------------------------------------------------------------------------------- #
Function AddClient()
{
	# Get client OS and hardware
	$uri = $baseUri + $hardwareUri
	$Response = Invoke-WebRequest -Method GET -Uri $uri -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
	$Response = (ConvertFrom-Json -InputObject $Response)
	$hardware = $response.data.attributes.hardware
	$os = $response.data.attributes.os
	Write-Host "The operating system for $clientName is $os, running on $hardware"
	
	# Add client
	$uri = $baseUri + $policiesUri + $policyName + "/clients/" + $clientName
	$data = @{
		type="client"
		attributes=@{
			hardware="$hardware"
			hostName="$clientName"
			OS="$os"
		}
	}
	$body = @{data=$data} | ConvertTo-Json -Depth 5
	Write-Host "Sending a request to add client $clientName to policy $policyName."
	$response = Invoke-WebRequest -Uri $uri -Method PUT -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
	if ($response.StatusCode -ne 201){
		throw "Unable to add  client $clientName to policy $policyName.`n"
	}
	Write-Host "$clientName added to $policyName successfully."
}
# ---------- End AddClient Definition ------------------------------------------------------------------------------------------------------------ #

# ---------- Start AddBackupSelection Definition ------------------------------------------------------------------------------------------------- #
Function AddBackupSelection()
{
	$uri = $baseUri + $policiesUri + $policyName + "/backupselections"
	$data = @{
		type="backupSelection"
		attributes=@{
			selections=@("$BackupSelection")
		}
	}
	$body = @{data=$data} | ConvertTo-Json -Depth 3
	Write-Host "Sending a request to backup $backupSelection with policy $policyName."
	$response = Invoke-WebRequest -Uri $uri -Method PUT -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
	if ($response.StatusCode -ne 204){
		throw "Unable to add $backupSelection to policy $policyName.`n"
	}
	Write-Host "Backup selection $backupSelection added to $policyName successfully."
}
# ---------- End AddBackupSelection Definition --------------------------------------------------------------------------------------------------- #

# ---------- Start AddSchedule Definition -------------------------------------------------------------------------------------------------------- #
Function AddSchedule()
{
	$uri = $baseUri + $policiesUri + $PolicyName + "/schedules/" + $ScheduleName
	$data = @{
		type="schedule"
		id=$scheduleName
		attributes=@{
			acceleratorForcedRescan=$false
			backupCopies=@{
				priority=9999
				copies=@(
					@{
						mediaOwner=$null
						storage=$null
						retentionPeriod=@{
							value=2
							unit="WEEKS"
						}
						volumePool=$null
						failStrategy="Continue"
					}
				)
			}
			backupType="Full Backup"
			excludeDates=@{}
			frequencySeconds=14400
			includeDates=@{}
			mediaMultiplexing=1
			retriesAllowedAfterRunDay=$false
			scheduleType="Frequency"
			snapshotOnly=$false
			startWindow=@(
				@{
					dayOfWeek=1
					startSeconds=0
					durationSeconds=604799
				}
			)
			syntheticBackup=$false
			storageIsSLP=$false
		}
	}
	$body = @{data=$data} | ConvertTo-Json -Depth 6
	Write-Host "Adding schedule $scheduleName to policy $policyName..."
	$response = Invoke-WebRequest -Uri $uri -Method PUT -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
			
	if ($response.StatusCode -ne 201){
		throw "Unable to add schedule $scheduleName to policy $policyName.`n"
	}
	Write-Host "Backup schedule $scheduleName added to $policyName successfully."
}
# ---------- End AddSchedule Definition ---------------------------------------------------------------------------------------------------------- #


# ----- Create the Windows Policy ------------------------------------------------ #
AddPolicy
AddClient
AddBackupSelection
AddSchedule
# ----- End Create Windows Policy ------------------------------------------------ #

# ----- Body variable for manual backup ----- #
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
$jsonBody = ($Body | ConvertTo-Json -Depth 10) # This converts the Body variable into JSON format
# ----- End body --------------------------- #

# ----- Run a backup then incrementally add files ------------------------------------------------ #
$backupCount = 31
for ($i=1; $i -le $backupCount; $i++){
	# Determine how many files to incrementally create -- 3% change rate
	$pathItems = Get-ChildItem $location.path -Recurse | measure | %{$_.count}
	$incremental = [Math]::Floor($pathItems * 0.03)
	# ----- Start a manual backup using API ----- #
	$uri = $baseUri + $backupUri
	$response = Invoke-RestMethod -Method POST -Uri $uri -Body $jsonBody -ContentType $content -Headers $header -SkipCertificateCheck
	$jobId = $response.data.attributes.jobId
	Write-Host "Backup $i of $backupCount started, the JobID is $JobId"
	# Delay 10 seconds to let the job start
	Start-Sleep -Seconds 10 
	
	# ----- Get the status of the backup job using API ----- #
	$uri = $baseUri + $jobsUri + $jobId
	$response = Invoke-RestMethod -Method GET -Uri $uri -ContentType $content -Headers $header -SkipCertificateCheck
	$state = $response.data.attributes.state
	# ----- Pause if a backup job is acitve or queued ----- #
	while ($state -eq 'ACTIVE' -or $state -eq 'QUEUED'){
		Start-Sleep -Seconds 3
		$response = Invoke-RestMethod -Method GET -Uri $uri -ContentType $content -Headers $header -SkipCertificateCheck
		$state = $Response.data.attributes.state
	}
	
	# ----- Incrementally add some files ----- #
	$j = $i % 10
	$targetPath = $pathNames[$j]
	$newPath = $location.path + '\' + $targetPath + '\'   
	for ($k=1; $k -le $incremental; $k++)
		{
			$out = new-object byte[] $fileSize; (new-object Random).NextBytes($out);
			$m = Get-Random
			[IO.File]::WriteAllBytes($newPath + "file_$m.txt", $out)			
		}
	Write-Host "Backup complete, added $incremental files to $newPath to simulate 3% change rate"
}
# End of script
