param(
    [Parameter(Mandatory=$true)]
    [string]$WebsiteName,
    
    [Parameter(Mandatory=$false)]
    [string]$Port = "80",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = ".\website_monitor.log"
)

# Function to get HTTP status code
function Get-WebsiteStatus {
    param (
        [string]$Url
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -ErrorAction Stop
        return @{
            StatusCode = $response.StatusCode
            StatusDescription = $response.StatusDescription
            Success = $true
        }
    }
    catch {
        if ($_.Exception.Response) {
            return @{
                StatusCode = $_.Exception.Response.StatusCode.value__
                StatusDescription = $_.Exception.Message
                Success = $false
            }
        } else {
            return @{
                StatusCode = 0
                StatusDescription = "Connection failed: $($_.Exception.Message)"
                Success = $false
            }
        }
    }
}

# Function to write to log file
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $LogPath -Value $logMessage
    Write-Host $logMessage
}

# Create log file if it doesn't exist
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType File -Path $LogPath -Force | Out-Null
}

Write-Log "Starting website monitoring for $WebsiteName"
Write-Log "Log file location: $LogPath"

$websiteUrl = "http://localhost:$Port"

while ($true) {
    $status = Get-WebsiteStatus -Url $websiteUrl
    
    if ($status.Success) {
        Write-Log "Status: $($status.StatusCode) - $($status.StatusDescription)"
        
        if ($status.StatusCode -ne 200) {
            Write-Log "ERROR: Website returned non-200 status code. Stopping website..."
            Stop-Website -Name $WebsiteName
            Write-Log "Website stopped. Please check the application for issues."
            break
        }
    }
    else {
        Write-Log "ERROR: Failed to connect to website. Status: $($status.StatusCode) - $($status.StatusDescription)"
        Write-Log "Stopping website..."
        Stop-Website -Name $WebsiteName
        Write-Log "Website stopped. Please check the application for issues."
        break
    }
    
    Start-Sleep -Seconds 60
}