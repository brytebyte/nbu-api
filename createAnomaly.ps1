<#
.SYNOPSIS
This simple script will create randomized files and several sub-folders in a root folder.
You control the number of files generated, and the size of these files, with the $fileCount and $fileSize variables.

.DESCRIPTION
This script can be run using NetBackup 10.2 and higher.
The policy name - win-4hr
The schedule name - win-4hr-full
The client name - console.lab.local

.EXAMPLE
./createAnomaly.ps1 -PrimaryServer <primaryServer> -ApiKey <api key>
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
# Department names for directories
$pathNames = @('Engineering', 'Finance', 'HR', 'Infrastructure', 'IT', 'Legal', 'Marketing', 'Operations', 'Sales', 'Veritas')
# Number of files to create
$fileCount = 505
# Set size of each randomized file - 10KB = 10240 1MB = 1048576 5MB = 5242880 10MB = 10485760 1GB = 1073741824
$fileSize = 102400

# Create directories and files
for ($d=0; $d -lt $pathNames.count; $d++){
	New-Item -Path $location.path -Name $pathNames[$d] -ItemType 'directory'
	$newPath = $location.path + '\' + $pathNames[$d] + '\'
	# Create files in each directory        
	for ($i=1; $i -le $fileCount; $i++){
			$out = new-object byte[] $fileSize; (new-object Random).NextBytes($out);           
			[IO.File]::WriteAllBytes($newPath + "file$i.txt", $out)
		}
}

# Run a single backup using NetBackup's API

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

# Start a manual backup using API
$url = "https://" + $PrimaryServer + "/netbackup/admin/manual-backup"
	$Response = Invoke-RestMethod -Method POST -Uri $Url -Body $JsonBody -ContentType $Content -Headers $Header -SkipCertificateCheck
$jobId = $Response.data.attributes.jobId
Write-Host "Backup started, the JobID is $JobId"

# End of script
