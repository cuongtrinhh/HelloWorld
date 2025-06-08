# IIS Website Deployment and Monitoring

This repository contains PowerShell scripts for deploying and monitoring a .NET Core web application on IIS.

## Prerequisites

- Windows Server or Windows 10/11 with IIS installed
- PowerShell 5.1 or later
- Administrator privileges
- .NET Core Hosting Bundle installed (for .NET Core applications)
- A zip file containing your web application

## Deployment Script (deploy.ps1)

The deployment script automates the process of setting up your web application on IIS.

### Parameters

- `WebAppZipPath` (Required): Path to your web application zip file
- `WebsiteName` (Required): Name for your IIS website
- `PhysicalPath` (Optional): Physical path for the website (default: C:\inetpub\wwwroot\$WebsiteName)
- `AppPoolName` (Optional): Name for the application pool (default: same as WebsiteName)
- `Port` (Optional): Port number for the website (default: 80)
- `AppPoolUser` (Required): Windows user account for the application pool
- `LocalGroupName` (Optional): Local group name for IIS users (default: IIS_AppPool_Users)

### Usage

```powershell
# Run as Administrator
.\deploy.ps1 -WebAppZipPath "C:\path\to\your\app.zip" -WebsiteName "MyWebsite" -AppPoolUser "IIS_AppPool_User" -Port 8080
```

## Monitoring Script (monitor.ps1)

The monitoring script continuously checks your website's health and logs its status.

### Parameters

- `WebsiteName` (Required): Name of the IIS website to monitor
- `Port` (Optional): Port number of the website (default: 80)
- `LogPath` (Optional): Path for the log file (default: .\website_monitor.log)

### Usage

```powershell
# Run in a separate PowerShell window
.\monitor.ps1 -WebsiteName "MyWebsite" -Port 8080
```

## Windows Service Installation (install-service.ps1)

The service installation script creates and configures a Windows service for your application.

### Parameters

- `ServiceName` (Required): Name of the Windows service
- `ExecutablePath` (Required): Full path to the executable file
- `ServiceUser` (Required): Windows user account to run the service
- `ServiceDisplayName` (Optional): Display name for the service
- `ServiceDescription` (Optional): Description of the service
- `RecoveryDelay` (Optional): Delay in seconds between recovery attempts (default: 300)

### Usage

```powershell
# Run as Administrator
.\install-service.ps1 -ServiceName "MyAppService" -ExecutablePath "C:\path\to\your\app.exe" -ServiceUser "DOMAIN\ServiceUser"
```

### Features

- Creates a Windows service with automatic startup
- Configures service to run under specified user account
- Sets up automatic recovery with 300-second delay between attempts
- Removes existing service if it exists
- Verifies service installation and status

## Complete Deployment and Monitoring Process

1. Open PowerShell as Administrator
2. Navigate to the script directory
3. Run the deployment script:
   ```powershell
   .\deploy.ps1 -WebAppZipPath "C:\path\to\your\app.zip" -WebsiteName "MyWebsite" -AppPoolUser "IIS_AppPool_User" -Port 8080
   ```
4. Install the Windows service:
   ```powershell
   .\install-service.ps1 -ServiceName "MyAppService" -ExecutablePath "C:\path\to\your\app.exe" -ServiceUser "DOMAIN\ServiceUser"
   ```

## Notes

- The deployment script must be run with Administrator privileges
- The monitoring script will create a log file in the specified location
- The website will be automatically stopped if the monitoring script detects any issues
- Make sure to set the correct password for the application pool user in IIS after deployment
- The Windows service will automatically start when the system boots
- The service will attempt to recover automatically every 300 seconds if it fails

# Windows Service Installation Script

This PowerShell script helps you install and configure a Windows service with various options.

## Prerequisites

- Windows PowerShell 5.1 or later
- Administrator privileges
- The executable file for your service

## Usage

### Basic Installation (Using Current User)

```powershell
.\install-service.ps1 -ServiceName "MyService" -ExecutablePath "C:\Path\To\Your\Service.exe"
```

### Installation with Custom User

```powershell
.\install-service.ps1 -ServiceName "MyService" -ExecutablePath "C:\Path\To\Your\Service.exe" -ServiceUser "DOMAIN\username" -ServicePassword "password"
```

### Full Options

```powershell
.\install-service.ps1 `
    -ServiceName "MyService" `
    -ExecutablePath "C:\Path\To\Your\Service.exe" `
    -ServiceDisplayName "My Custom Service" `
    -ServiceDescription "Description of my service" `
    -RecoveryDelay "300" `
    -ServiceUser "DOMAIN\username" `
    -ServicePassword "password"
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| ServiceName | Yes | Name of the Windows service |
| ExecutablePath | Yes | Full path to the service executable |
| ServiceDisplayName | No | Display name for the service (defaults to ServiceName) |
| ServiceDescription | No | Description of the service |
| RecoveryDelay | No | Delay in seconds between service restart attempts (default: 300) |
| ServiceUser | No | Custom user account to run the service (if not specified, uses current user) |
| ServicePassword | No | Password for the custom user account |

## Features

- Creates and configures a Windows service
- Supports custom user accounts or current user
- Configures service recovery options
- Sets appropriate permissions
- Handles service removal if it already exists
- Configures "Log on as a service" right for custom users

## Notes

1. The script must be run as Administrator
2. If using a custom user:
   - The user must exist
   - The user must have a password
   - The user will be granted "Log on as a service" right
3. If no custom user is specified, the service will run as the current user
4. The script will automatically remove any existing service with the same name