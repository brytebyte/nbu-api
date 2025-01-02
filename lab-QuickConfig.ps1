# -----| lab-QuickConfig.ps1 |------ #
# Author: Dave Chambers
# Last updated:	6/12/2024
# Tested using:	PowerShell v7.4.2
# ---------------------------------- #

<#
.SYNOPSIS
This script performs the initial configuration of a NetBackup lab environment.

.DESCRIPTION
There are some basic housekeeping tasks to be completed when initially configuring a NetBackup lab.  This script creates an admin user 
NetBackup API key, then sets the initial DR password, then creates a catalog backup policy with provided parameters.
It can be run using NetBackup 10.4 and higher, and was tested using PowerShell 7.4.2.

This is a DEMO script - it should NOT be used in PRODUCTION without modification.

.PARAMETER primaryServer
This is the FQDN of your NetBackup primary server.
.PARAMETER userName
This is the name of the user configuring the lab.
.PARAMETER password
This is the password for the user configuring the lab.
.EXAMPLE
./quick-LabConfig.ps1 -primaryServer nbuprimary.lab.local -userName dave.chambers -password We!come10
#>

Param (
	[Parameter(Mandatory)][string]$primaryServer,
	[Parameter(Mandatory)][string]$userName,
	[Parameter(Mandatory)][string]$password
)

# ----- API variables --------------------------------- #
$content = "application/vnd.netbackup+json;version=9.0"
$baseUri = "https://" + $primaryServer + "/netbackup/"
$loginUri = "login"
$apiUri = "security/api-keys"
$drUri = "security/credentials/DR_PKG_KEY/isset"
$credsUri = "security/credentials"
$policiesUri = "config/policies/"
# ----- END API variables ----------------------------- #


# Split FQDN into just the hostname
$hostName = $primaryServer.split(".")
Write-Host "The hostname is" $hostName[0]


# ----- Create Access Token ------------------------------------------------------------------------------------ #
$body = @{
	domainType = 'unixpwd'
	domainName = $hostname[0]
	userName = $userName
	password = $password
}
$jsonBody = ($body | ConvertTo-Json)
# Set API endpoint /netbackup/login
$uri = $baseUri + $loginUri

$response = Invoke-RestMethod -Method POST -Uri $uri -Body $jsonBody -ContentType $content -SkipCertificateCheck
$authToken = $response.token  # Now $authToken will contain the NetBackup access token
Write-Host "The AuthToken is $AuthToken"
# ----- END create access token -------------------------------------------------------------------------------- #


# ----- Using access token, create an API key --------------------------------------------------------------------------------------------------- #
$header = [ordered]@{ Authorization = $authToken }
$data = @{
	type = "apiKeyCreationRequest"
	attributes = @{
		expireAfterDays = "P365D"
		userName = $userName
		userDomain = ""
		userDomainType = "unixpwd"
		description = "New API key for $userName"
	}
}
$body = @{data=$data} | ConvertTo-Json -Depth 5
# Set API endpoint /netbackup/security/api-keys
$uri = $baseUri + $apiUri

$response = Invoke-WebRequest -Method POST -Uri $uri -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
$converted = $response | ConvertFrom-Json -Depth 5
$apiKey = $converted.data.attributes.apiKey
# Save the API key to a file
$filePath = "C:\Utils\apiKey.txt"
$apiString = "The new API key for $userName is $apiKey"
$apiString | Out-File -FilePath $filePath
Write-Host "The new API key for $username is $apiKey"
# ----- END create API key ---------------------------------------------------------------------------------------------------------------------- #


# ----- New header variable using the api key-----
$header = [ordered]@{ Authorization = $apiKey }
# ------------------------------------------------


# ----- Set the DR password --------------------------------------------------------------------------------------------------------------------- #
# Set API endpoint /netbackup/security/credentials/DR_PKG_KEY/isset
$uri = $baseUri + $drUri

$response = Invoke-WebRequest -Method GET -Uri $uri -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
$response = (ConvertFrom-Json -InputObject $response)
if($response){
	Write-Host "The DR password was already set."
} else {
	# Set the DR password
	Write-Host "Setting the DR password."
	# Set API endpoint /netbackup/security/credentials
	$uri = $baseUri + $credsUri
	$body = @{
		credName="DR_PKG_KEY"
		credValue="We!come10"
		}
	$body = $body | ConvertTo-Json -Depth 5
	$response = Invoke-WebRequest -Method PUT -Uri $uri -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing
	if ($response.StatusCode -eq 200){
		Write-Host "The DR password has been set."
	} else {
		Write-Host "The DR password could NOT be set."
	}
}
# ----- END set DR password---------------------------------------------------------------------------------------------------------------------- #

# ----- Create the Catalog backup policy -------------------------------------------------------------------------------------------------------- #
$policyName = "catalog-8hr"
$policyType = "NBU-Catalog"

# Set API endpoint /netbackup/config/policies/
$uri = $baseUri + $policiesUri
$data = @{
	type = "policy"
	id = $policyName
    attributes = @{
		policy = @{
			policyName = $policyName
			policyType = $policyType
			policyAttributes = @{
				active = $true
				disableClientSideDeduplication = $false
				mediaOwner = "*ANY*"
				priority = 0
				secondarySnapshotMethodArgs = $null
				snapshotMethod = $null
				snapshotMethodArgs = $null
				storage = "MSDPSTU"
				storageIsSLP = $false
				volumePool = "CatalogBackup"
            }
			schedules = @(
				# Full backup once a day, retain for 2 weeks
				@{
					backupCopies = @{
						copies =@(
							@{
								failStrategy = $null
								mediaOwner = $null
								retentionPeriod = @{
									value = 2
									unit = "WEEKS"
                                }
								retentionLevel = 1
								storage = $null
								volumePool = $null
                            }
                        )
						priority = -1
                    }
					backupType = "Full Backup"
					excludeDates = @{
						lastDayOfMonth = $false
						recurringDaysOfMonth = @()
						recurringDaysOfWeek = @()
						specificDates = @()
                    }
					frequencySeconds = 86400
					mediaMultiplexing = 1
					scheduleName = "catalog-8hr-full"
					scheduleType = "Frequency"
					snapshotOnly = $false
                    startWindow = @(
                            @{
                                dayOfWeek = 1
                                startSeconds = 0
                                durationSeconds = 604799
                            }
                        )
                    storageIsSLP = $false
                    syntheticBackup = $false
                }
				# Differential incremental every 8 hours, retain for 23 hours
				@{
					backupCopies = @{
						copies = @(
							@{
								failStrategy = $null
								mediaOwner = $null
								retentionPeriod = @{
									value = 23
									unit = "HOURS"
									}
								retentionLevel = 0
								storage = $null
								volumePool = $null
							}
						)
						priority = -1
                    }
					backupType = "Cumulative Incremental Backup"
                    excludeDates = @{
						lastDayOfMonth = $false
						recurringDaysOfMonth = @()
						recurringDaysOfWeek = @()
						specificDates = @()
                    }
					frequencySeconds = 28800
					mediaMultiplexing = 1
					scheduleName = "catalog-8hr-incr"
					scheduleType = "Frequency"
					snapshotOnly = $false
                    startWindow = @(
                            @{
                                dayOfWeek = 1
                                startSeconds = 0
                                durationSeconds = 604799
                            }
                        )
                    storageIsSLP = $false
                    syntheticBackup = $false
                }
            )
			catDRInfo = @{
				path = "/home/dave.chambers"
				userName = "dave.chambers"
				password = "We!come10"
				classNames = @()
            }
        }
    }
}
$body = @{data=$data} | ConvertTo-Json -Depth 10
Write-Host "`nSending a request to create $policyName."
$response = Invoke-WebRequest -Method POST -Uri $uri -Body $body -ContentType $content -Headers $header -SkipCertificateCheck -UseBasicParsing		
if ($response.StatusCode -ne 204){
	throw "Unable to create policy $policyName."
}
Write-Host "$policyName created successfully.`n"

# ----- END script ------------------------------------------------------------------------------------------------------------------------------ #
