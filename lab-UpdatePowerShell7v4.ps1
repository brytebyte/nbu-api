# -----| update-PS7v4.ps1 |------ #
# Author: Dave Chambers
# Last updated:	1/23/2023
# Tested using:	PowerShell v7.4.2
# ---------------------------------- #

# ----- This script updates PowerShell to version 7 and installs the AWSPowerShell module ----- #

# ----- Use TLS 1.2, update NuGet, make the PowerShell Gallery rpo a trusted resource ----- #
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# ----- Install the AWS module ----- #
Install-Module -Name AWSPowerShell -allowclobber

# ----- Install PowerShell 7 ----- #
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet -AddExplorerContextMenu -EnablePSRemoting"

# ----- Create the Utils directory and add it to the Quick Access list ----- #
New-Item -Path "C:\" -Name "Utils" -ItemType "directory"
$o = new-object -com shell.application
$o.Namespace('C:\Utils').Self.InvokeVerb("pintohome")
cd C:\Utils
# ----- End script ---------------------------------------------------------------------------- #
