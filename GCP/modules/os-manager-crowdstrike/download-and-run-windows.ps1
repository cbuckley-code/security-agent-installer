# CrowdStrike Download and Install Script for Windows
# This script downloads and installs CrowdStrike with custom parameters from GCS

param(
    [string]$ScriptArgs = "${script_args}",
    [string]$GcsInstallerPath = "${gcs_installer_path}",
    [string]$CrowdStrikeCID = "${crowdstrike_cid}",
    [string]$ProjectId = "${project_id}"
)

$ErrorActionPreference = "Stop"

# Get metadata
$Hostname = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Output "[$Timestamp] Starting CrowdStrike download and install on $Hostname"
Write-Output "[$Timestamp] GCS installer path: $GcsInstallerPath"
Write-Output "[$Timestamp] Install arguments: $ScriptArgs"

# Validate that CrowdStrike CID is provided
if (-not $CrowdStrikeCID -or $CrowdStrikeCID.Trim() -eq "") {
    Write-Error "CrowdStrike Customer ID (CID) is required but not provided. Cannot proceed with installation."
    exit 1
}
Write-Output "[$Timestamp] CrowdStrike CID provided: $($CrowdStrikeCID.Substring(0, 8))..."

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You are not running as an Administrator. Please try again with admin privileges."
    exit 1
}

# Check if CrowdStrike Agent is already running
if (Get-Process -Name CSFalconService -ErrorAction SilentlyContinue) {
    Write-Output "CrowdStrike Agent is already running."
    exit 0
}

Write-Output "[$Timestamp] CrowdStrike Agent download started"

# Extract filename from GCS path
$InstallFile = Split-Path $GcsInstallerPath -Leaf
$InstallDir = $env:TEMP
$LocalPath = Join-Path $InstallDir $InstallFile

Write-Output "[$Timestamp] Download CrowdStrike Agent Package"

# Download from GCS using gsutil (assumes gcloud SDK is installed)
try {
    $gsutilCmd = "gsutil cp `"$GcsInstallerPath`" `"$LocalPath`""
    Write-Output "[$Timestamp] Running: $gsutilCmd"
    Invoke-Expression $gsutilCmd
    
    if (-not (Test-Path $LocalPath)) {
        throw "File not found after download"
    }
    
    $fileSize = (Get-Item $LocalPath).length
    if ($fileSize -eq 0) {
        throw "Downloaded file is empty"
    }
    
    Write-Output "[$Timestamp] Downloaded File Size: $fileSize bytes"
} catch {
    Write-Output "Failed to download the CrowdStrike Agent for Windows from GCS bucket."
    Write-Output "Error: $($_.Exception.Message)"
    exit 1
}

Write-Output "[$Timestamp] CrowdStrike Agent install started"

# Prepare installation arguments
$InstallArgs = @("/install", "/quiet", "/norestart")

# Add CID if provided
if ($CrowdStrikeCID) {
    $InstallArgs += "CID=$CrowdStrikeCID"
}

# Add any additional custom arguments
if ($ScriptArgs) {
    $AdditionalArgs = $ScriptArgs -split '\s+'
    $InstallArgs += $AdditionalArgs
}

try {
    Write-Output "[$Timestamp] Running installer with arguments: $($InstallArgs -join ' ')"
    $Process = Start-Process -FilePath $LocalPath -ArgumentList $InstallArgs -Wait -PassThru
    $ExitCode = $Process.ExitCode
    
    Write-Output "[$Timestamp] Installer Exit Code: $ExitCode"
    
    if ($ExitCode -ne 0 -and $ExitCode -ne 3010) { # 3010 is success but reboot required
        throw "Installation failed with exit code: $ExitCode"
    }
    
    Write-Output "[$Timestamp] CrowdStrike Agent installation completed successfully"
    
} catch {
    Write-Output "Failed to install CrowdStrike Agent."
    Write-Output "Error: $($_.Exception.Message)"
    exit 1
} finally {
    # Clean up downloaded file
    if (Test-Path $LocalPath) {
        Remove-Item $LocalPath -Force
        Write-Output "[$Timestamp] Cleaned up installer file"
    }
}

# Log to Cloud Logging
try {
    $LogEntry = @{
        severity = "INFO"
        message = "CrowdStrike installation completed"
        hostname = $Hostname
        gcs_path = $GcsInstallerPath
        arguments = $ScriptArgs
        exit_code = $ExitCode
    } | ConvertTo-Json

    gcloud logging write crowdstrike-install $LogEntry --project=$ProjectId
} catch {
    Write-Output "Failed to write to Cloud Logging: $($_.Exception.Message)"
}

Write-Output "[$Timestamp] CrowdStrike Agent Deployment Finished"
Write-Output "[$Timestamp] CrowdStrike Agent Deployment Script Finished"

exit 0
