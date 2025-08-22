#!/bin/bash
# CrowdStrike Download and Install Script for Linux
# This script downloads and installs CrowdStrike with custom parameters from GCS
# Mirrors the functionality of the AWS SSM document

set -euo pipefail

SCRIPT_ARGS="${script_args}"
GCS_INSTALLER_PATH="${gcs_installer_path}"
CROWDSTRIKE_CID="${crowdstrike_cid}"
PROJECT_ID="${project_id}"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting CrowdStrike download and install on $HOSTNAME"
echo "[$TIMESTAMP] GCS installer path: $GCS_INSTALLER_PATH"
echo "[$TIMESTAMP] Install arguments: $SCRIPT_ARGS"

# Validate that CrowdStrike CID is provided
if [[ -z "$CROWDSTRIKE_CID" ]]; then
    echo "ERROR: CrowdStrike Customer ID (CID) is required but not provided. Cannot proceed with installation."
    logger -t "crowdstrike-install" "CrowdStrike Customer ID (CID) is required but not provided."
    exit 1
fi
echo "[$TIMESTAMP] CrowdStrike CID provided: ${CROWDSTRIKE_CID:0:8}..."

# Check if running as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "You are not running as the root user. Please try again with root privileges to install the CrowdStrike Agent."
    logger -t "crowdstrike-install" "You are not running as the root user. Please try again with root privileges to install the CrowdStrike Agent."
    exit 1
fi

# Check if CrowdStrike Agent is already running
if ps -ef | grep falcon-sensor | grep -v grep > /dev/null 2>&1; then
    echo "CrowdStrike Agent is already running."
    logger -t "crowdstrike-install" "CrowdStrike Agent is already running."
    exit 0
fi

# Detect OS and version
instance_os=$(cat /etc/*-release | grep '^NAME' | sed 's/^.*="\([^"]*\)"/\1/')
os_major_ver=$(cat /etc/*-release | grep '^VERSION_ID'| sed 's/^.*="\([^"]*\)"/\1/' | cut -d"." -f1)

echo "[$TIMESTAMP] Detected OS: $instance_os"
echo "[$TIMESTAMP] Detected OS Major Version: $os_major_ver"

# Ensure gsutil is available (part of gcloud SDK)
if ! command -v gsutil &> /dev/null; then
    echo "[$TIMESTAMP] gsutil not found, attempting to install gcloud SDK..."
    
    # Install gcloud SDK based on OS
    if [[ $instance_os =~ ^Red.* ]] || [[ $instance_os =~ ^CentOS.* ]] || [[ $instance_os =~ ^Rocky.* ]] || [[ $instance_os =~ ^AlmaLinux.* ]] || [[ $instance_os =~ ^Fedora.* ]]; then
        sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
        sudo yum install -y google-cloud-sdk
    elif [[ $instance_os =~ ^SLES.* ]] || [[ $instance_os =~ ^SUSE.* ]]; then
        echo "Please install gcloud SDK manually for SLES/SUSE"
        exit 1
    elif [[ $instance_os =~ ^Ubuntu.* ]] || [[ $instance_os =~ ^Debian.* ]]; then
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        sudo apt-get update && sudo apt-get install -y google-cloud-sdk
    else
        echo "Unsupported platform for automatic gcloud SDK installation: $instance_os"
        exit 1
    fi
fi

# Determine the appropriate installer filename based on OS
if [[ $instance_os =~ ^Red.* ]] || [[ $instance_os =~ ^CentOS.* ]] || [[ $instance_os =~ ^Rocky.* ]] || [[ $instance_os =~ ^AlmaLinux.* ]] || [[ $instance_os =~ ^Fedora.* ]]; then
    s3filename="falcon-sensor-el${os_major_ver}.x86_64.rpm"
elif [[ $instance_os =~ ^SLES.* ]] || [[ $instance_os =~ ^SUSE.* ]]; then
    s3filename="falcon-sensor-suse${os_major_ver}.x86_64.rpm"
elif [[ $instance_os =~ ^Ubuntu.* ]] || [[ $instance_os =~ ^Debian.* ]]; then
    s3filename="falcon-sensor-amd64.deb"
else
    echo "Unsupported platform is detected for CrowdStrike Agent install: $instance_os"
    logger -t "crowdstrike-install" "Unsupported platform is detected for CrowdStrike Agent install: $instance_os"
    exit 1
fi

# Override filename if a specific path is provided
if [[ $GCS_INSTALLER_PATH == *.* ]]; then
    s3filename=$(basename "$GCS_INSTALLER_PATH")
    GCS_BASE_PATH=$(dirname "$GCS_INSTALLER_PATH")
else
    GCS_BASE_PATH="$GCS_INSTALLER_PATH"
fi

FULL_GCS_PATH="${GCS_BASE_PATH}/${s3filename}"
INSTALL_DIR="/tmp"
LOCAL_PATH="${INSTALL_DIR}/${s3filename}"

echo "[$TIMESTAMP] Target installer: $s3filename"
echo "[$TIMESTAMP] Full GCS path: $FULL_GCS_PATH"

# Download CrowdStrike installer from GCS
echo "[$TIMESTAMP] Downloading CrowdStrike installer from GCS..."
cd "$INSTALL_DIR"

# Use gsutil to download from GCS
if gsutil cp "$FULL_GCS_PATH" "$LOCAL_PATH"; then
    echo "[$TIMESTAMP] Successfully downloaded $s3filename from GCS"
else
    echo "[$TIMESTAMP] ERROR: Failed to download installer from GCS"
    logger -t "crowdstrike-install" "Failed to download the CrowdStrike Agent package from GCS."
    exit 1
fi

# Verify the file was downloaded
if [[ ! -f "$LOCAL_PATH" ]]; then
    echo "[$TIMESTAMP] ERROR: Installer file not found after download"
    exit 1
fi

echo "[$TIMESTAMP] Downloaded file size: $(ls -lh "$LOCAL_PATH" | awk '{print $5}')"

# Install CrowdStrike package
echo "[$TIMESTAMP] Installing CrowdStrike Agent package..."
logger -t "crowdstrike-install" "Installing CrowdStrike Agent package..."

rc=1
if [[ $instance_os =~ ^SLES.* ]]; then
    sudo zypper --no-gpg-checks install -y "$LOCAL_PATH"
    rc=$?
elif [[ $s3filename =~ .*rpm$ ]]; then
    sudo yum install -y "$LOCAL_PATH"
    rc=$?
elif [[ $s3filename =~ .*deb$ ]]; then
    sudo apt update
    sudo apt install -y "$LOCAL_PATH"
    rc=$?
else
    echo "Failed to determine installation method for CrowdStrike Agent package."
    logger -t "crowdstrike-install" "Failed to determine installation method for CrowdStrike Agent package."
    exit 1
fi

if [[ $rc != 0 ]]; then
    echo "Failed to install the CrowdStrike Agent package."
    logger -t "crowdstrike-install" "Failed to install the CrowdStrike Agent package."
    exit 1
fi

echo "[$TIMESTAMP] Installed the CrowdStrike Agent package successfully."
logger -t "crowdstrike-install" "Installed the CrowdStrike Agent package successfully."

# Configure CrowdStrike with CID if provided
if [[ -n "$CROWDSTRIKE_CID" ]]; then
    echo "[$TIMESTAMP] Configuring CrowdStrike with CID: $CROWDSTRIKE_CID"
    sudo /opt/CrowdStrike/falconctl -f -s --cid="$CROWDSTRIKE_CID"
    rc=$?
    
    if [[ $rc != 0 ]]; then
        echo "Failed to link CrowdStrike Agent to CID."
        logger -t "crowdstrike-install" "Failed to link CrowdStrike Agent to CID."
        exit 1
    fi
    
    # Restart the falcon-sensor service
    sudo service falcon-sensor restart
    rc=$?
    
    if [[ $rc != 0 ]]; then
        echo "Failed to restart the CrowdStrike Agent service."
        logger -t "crowdstrike-install" "Failed to restart the CrowdStrike Agent service."
        exit 1
    fi
    
    echo "[$TIMESTAMP] CrowdStrike Agent configured and started successfully."
fi

echo "[$TIMESTAMP] CrowdStrike installation completed successfully"

# Clean up downloaded file
rm -f "$LOCAL_PATH"
echo "[$TIMESTAMP] Cleaned up installer file"

# Log to Cloud Logging
gcloud logging write crowdstrike-install \
    "{\"severity\":\"INFO\",\"message\":\"CrowdStrike installation completed\",\"hostname\":\"$HOSTNAME\",\"gcs_path\":\"$FULL_GCS_PATH\",\"arguments\":\"$SCRIPT_ARGS\",\"os\":\"$instance_os\",\"os_version\":\"$os_major_ver\"}" \
    --project="$PROJECT_ID" || true

exit 0
