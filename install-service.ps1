param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    
    [Parameter(Mandatory=$true)]
    [string]$ExecutablePath,
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceDisplayName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceDescription = "Windows Service for application monitoring",
    
    [Parameter(Mandatory=$false)]
    [string]$RecoveryDelay = "300",

    [Parameter(Mandatory=$false)]
    [string]$ServiceUser,

    [Parameter(Mandatory=$false)]
    [string]$ServicePassword
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Please run this script as Administrator"
    exit 1
}

# Check if executable exists
if (-not (Test-Path $ExecutablePath)) {
    Write-Error "Executable file not found at: $ExecutablePath"
    exit 1
}

# Validate custom user parameters
if ($ServiceUser -and -not $ServicePassword) {
    Write-Error "ServicePassword is required when using a custom ServiceUser"
    exit 1
}

if (-not $ServiceUser -and $ServicePassword) {
    Write-Error "ServiceUser is required when specifying ServicePassword"
    exit 1
}

# Set default display name if not provided
if (-not $ServiceDisplayName) {
    $ServiceDisplayName = $ServiceName
}

# Determine service account
if ($ServiceUser) {
    Write-Host "Using custom service account: $ServiceUser"
    $serviceAccount = $ServiceUser
} else {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $computerName = $env:COMPUTERNAME
    $userName = $currentUser.Split('\')[-1]
    $serviceAccount = "$computerName\$userName"
    Write-Host "No custom user specified. Using current user: $serviceAccount"
}

# Check if service already exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Service '$ServiceName' already exists. Stopping and removing it..."
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Remove service using sc.exe
    Write-Host "Removing existing service..."
    $sc = "sc.exe"
    & $sc delete $ServiceName
    Start-Sleep -Seconds 2
    
    # Verify service is removed
    $serviceStillExists = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($serviceStillExists) {
        Write-Error "Failed to remove existing service. Please remove it manually and try again."
        exit 1
    }
}

# Create the service
Write-Host "Creating service '$ServiceName'..."
if ($ServiceUser -and $ServicePassword) {
    Write-Host "Creating service with custom user credentials..."
    $securePassword = ConvertTo-SecureString $ServicePassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($ServiceUser, $securePassword)
    New-Service -Name $ServiceName `
                -BinaryPathName $ExecutablePath `
                -DisplayName $ServiceDisplayName `
                -Description $ServiceDescription `
                -StartupType Automatic `
                -Credential $credential
} else {
    Write-Host "Creating service with current user..."
    New-Service -Name $ServiceName `
                -BinaryPathName $ExecutablePath `
                -DisplayName $ServiceDisplayName `
                -Description $ServiceDescription `
                -StartupType Automatic
}

# Configure service to run as specified account
Write-Host "Configuring service to run as: $serviceAccount"
$sc = "sc.exe"
if ($ServiceUser -and $ServicePassword) {
    Write-Host "Configuring service with custom user credentials..."
    & $sc config $ServiceName obj= $ServiceUser password= $ServicePassword
} else {
    Write-Host "Configuring service with current user..."
    & $sc config $ServiceName obj= $serviceAccount
}

# Grant necessary permissions to the service registry key
Write-Host "Granting necessary permissions..."
$acl = Get-Acl "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
$rule = New-Object System.Security.AccessControl.RegistryAccessRule($serviceAccount, "FullControl", "Allow")
$acl.SetAccessRule($rule)
Set-Acl "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" $acl

# Add the service account to the "Log on as a service" right if using custom user
if ($ServiceUser) {
    Write-Host "Adding user to 'Log on as a service' right..."
    $secedit = "secedit.exe"
    $tempFile = [System.IO.Path]::GetTempFileName()
    & $secedit /export /cfg $tempFile
    $secConfig = Get-Content $tempFile
    $secConfig = $secConfig -replace "SeServiceLogonRight = .*", "SeServiceLogonRight = *$ServiceUser"
    $secConfig | Set-Content $tempFile
    & $secedit /configure /db secedit.sdb /cfg $tempFile
    Remove-Item $tempFile -Force
}

# Grant permissions to the executable
Write-Host "Granting permissions to executable..."
$exeAcl = Get-Acl $ExecutablePath
$exeRule = New-Object System.Security.AccessControl.FileSystemAccessRule($serviceAccount, "FullControl", "Allow")
$exeAcl.SetAccessRule($exeRule)
Set-Acl $ExecutablePath $exeAcl

# Configure service recovery options
Write-Host "Configuring service recovery options..."
& $sc failure $ServiceName reset= 86400 actions= restart/$RecoveryDelay/restart/$RecoveryDelay/restart/$RecoveryDelay

# Start the service
Write-Host "Starting service..."
Start-Service -Name $ServiceName

# Verify service status
$service = Get-Service -Name $ServiceName
Write-Host "Service Status: $($service.Status)"
Write-Host "Startup Type: $($service.StartType)"

Write-Host "Service installation completed successfully!"
Write-Host "Service Name: $ServiceName"
Write-Host "Display Name: $ServiceDisplayName"
Write-Host "Executable Path: $ExecutablePath"
Write-Host "Service Account: $serviceAccount"
Write-Host "Recovery Delay: $RecoveryDelay seconds" 