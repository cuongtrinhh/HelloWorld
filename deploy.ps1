# IIS Deployment Script
param(
    [Parameter(Mandatory=$true)]
    [string]$WebAppZipPath,
    
    [Parameter(Mandatory=$true)]
    [string]$WebsiteName,
    
    [Parameter(Mandatory=$false)]
    [string]$PhysicalPath = "C:\inetpub\wwwroot\$WebsiteName",
    
    [Parameter(Mandatory=$false)]
    [string]$AppPoolName = $WebsiteName,
    
    [Parameter(Mandatory=$false)]
    [string]$Port = "80",

    [Parameter(Mandatory=$true)]
    [string]$AppPoolUser,

    [Parameter(Mandatory=$false)]
    [string]$LocalGroupName = "IIS_AppPool_Users"
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Please run this script as Administrator"
    exit 1
}

# Check if Web-Server feature is installed
$feature = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
if ($feature.State -ne "Enabled") {
    Write-Host "Installing Web Server (IIS) feature..."
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All
}

# Check if .NET Core Hosting Bundle is installed
$dotnetHostingBundle = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Hosting*" }
if (-not $dotnetHostingBundle) {
    Write-Error ".NET Core Hosting Bundle is not installed. Please install it from: https://dotnet.microsoft.com/download/dotnet/9.0"
    exit 1
}

Write-Host "Found .NET Core Hosting Bundle: $($dotnetHostingBundle.Name)"

# Create physical path if it doesn't exist
if (-not (Test-Path $PhysicalPath)) {
    Write-Host "Creating physical path: $PhysicalPath"
    New-Item -ItemType Directory -Path $PhysicalPath -Force | Out-Null
}

# Create logs directory first and set permissions
$logsPath = Join-Path $PhysicalPath "logs"
if (-not (Test-Path $logsPath)) {
    Write-Host "Creating logs directory: $logsPath"
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Extract the zip file
Write-Host "Extracting web application to $PhysicalPath..."
Expand-Archive -Path $WebAppZipPath -DestinationPath $PhysicalPath -Force

# Create local group and add user if it doesn't exist
Write-Host "Checking local group: $LocalGroupName"
$group = Get-LocalGroup -Name $LocalGroupName -ErrorAction SilentlyContinue
if (-not $group) {
    Write-Host "Creating local group: $LocalGroupName"
    New-LocalGroup -Name $LocalGroupName -Description "IIS Application Pool Users"
}

# Check if user exists, if not create it
$user = Get-LocalUser -Name $AppPoolUser -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Host "Creating local user: $AppPoolUser"
    $password = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
    New-LocalUser -Name $AppPoolUser -Password $password -Description "IIS Application Pool User" | Out-Null
    Add-LocalGroupMember -Group "Users" -Member $AppPoolUser
}

# Add user to the group if not already a member
$isMember = Get-LocalGroupMember -Group $LocalGroupName -Member $AppPoolUser -ErrorAction SilentlyContinue
if (-not $isMember) {
    Write-Host "Adding user $AppPoolUser to group $LocalGroupName"
    Add-LocalGroupMember -Group $LocalGroupName -Member $AppPoolUser
}

# Remove existing application pool if it exists
$existingAppPool = Get-IISAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
if ($existingAppPool) {
    Write-Host "Removing existing application pool: $AppPoolName"
    Remove-WebAppPool -Name $AppPoolName
    Start-Sleep -Seconds 2
}

# Create new application pool
Write-Host "Creating application pool: $AppPoolName"
$appPool = New-WebAppPool -Name $AppPoolName -Force

# Configure application pool settings
Write-Host "Configuring application pool settings..."
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ""
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedPipelineMode -Value 1  # 1 = Integrated
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name startMode -Value "AlwaysRunning"
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.identityType -Value 3  # 3 = SpecificUser
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.userName -Value $AppPoolUser
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.password -Value "P@ssw0rd"  # Default password, change this in IIS

# Remove existing website if it exists
$existingWebsite = Get-Website -Name $WebsiteName -ErrorAction SilentlyContinue
if ($existingWebsite) {
    Write-Host "Removing existing website: $WebsiteName"
    Stop-Website -Name $WebsiteName
    Remove-Website -Name $WebsiteName
    Start-Sleep -Seconds 2
}

# Create new website
Write-Host "Creating website: $WebsiteName"
New-Website -Name $WebsiteName -PhysicalPath $PhysicalPath -ApplicationPool $AppPoolName -Port $Port

# Configure web.config if it doesn't exist
$webConfigPath = Join-Path $PhysicalPath "web.config"
if (-not (Test-Path $webConfigPath)) {
    Write-Host "Creating web.config..."
    @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet" arguments=".\HelloWorld.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
  </system.webServer>
</configuration>
"@ | Out-File -FilePath $webConfigPath -Encoding UTF8
}

# Set permissions for the entire website directory
Write-Host "Setting permissions..."
$acl = Get-Acl $PhysicalPath

# Grant full control to the application pool user
$appPoolUserRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AppPoolUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($appPoolUserRule)

# Grant modify access to IIS_IUSRS
$iisUsersRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($iisUsersRule)

# Grant modify access to the local group
$groupAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($LocalGroupName, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($groupAccessRule)

# Apply permissions
Set-Acl $PhysicalPath $acl

# Set specific permissions for logs directory
$logsAcl = Get-Acl $logsPath
$logsAcl.SetAccessRule($appPoolUserRule)
$logsAcl.SetAccessRule($iisUsersRule)
$logsAcl.SetAccessRule($groupAccessRule)
Set-Acl $logsPath $logsAcl

# Start the website
Write-Host "Starting website..."
Start-Website -Name $WebsiteName

# Verify website is running
$website = Get-Website -Name $WebsiteName
if ($website.State -ne "Started") {
    Write-Error "Website failed to start. Please check the application pool and website configuration in IIS."
    exit 1
}

# Verify application pool is running
$appPool = Get-IISAppPool -Name $AppPoolName
if ($appPool.State -ne "Started") {
    Write-Error "Application pool failed to start. Please check the application pool configuration in IIS."
    exit 1
}

Write-Host "Deployment completed successfully!"
Write-Host "Website URL: http://localhost:$Port"
Write-Host "IMPORTANT: Please change the application pool user password in IIS after deployment!"