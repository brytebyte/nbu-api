# This script updates PowerShell to version 7, creates a "Utils" directory, and creates some test data
# 
# Written by:  Dave Chambers
# Last Updated: 5/7/2023
#
# Typically used to build out a NetBackup security demo

#Use TLS 1.2, update NuGet, make the PowerShell Gallery rpo a trusted resource
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

#Install PowerShell 7
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet -AddExplorerContextMenu -EnablePSRemoting"

#Create the Utils directory and add it to the Quick Access list
New-Item -Path "C:\" -Name "Utils" -ItemType "directory"
$o = new-object -com shell.application
$o.Namespace('C:\Utils').Self.InvokeVerb("pintohome")
cd C:\Utils

# Current path
$location = Get-Location
# Initial directories
$pathNames = @('Engineering', 'Operations', 'Security', 'HR', 'Sales')
# Number of files to create
$fileCount = 201
# Set size of each randomized file - 10KB = 10240 1MB = 1048576 5MB = 5242880 10MB = 10485760 1GB = 1073741824
$fileSize = 10240
   
# Create directories and dummy files
for ($d=0; $d -lt $pathNames.count; $d++){
	New-Item -Path $location.path -Name $pathNames[$d] -ItemType 'directory'
	$newPath = $location.path + '\' + $pathNames[$d] + '\'
	# Create files in each directory        
	for ($i=1; $i -le $fileCount; $i++)
		{
			$out = new-object byte[] $fileSize; (new-object Random).NextBytes($out);           
			[IO.File]::WriteAllBytes($newPath + "file$i.txt", $out)
		}
}
# End of script
