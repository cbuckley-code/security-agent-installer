# CrowdStrike Agent Installation: AWS SSM to GCP VM Manager Conversion

This document explains how the AWS Systems Manager (SSM) document for CrowdStrike installation has been converted to use Google Cloud Platform's VM Manager (OS Config).

## AWS vs GCP Comparison

### AWS SSM Document Structure
The original AWS implementation used:
- **AWS SSM Document** with `Command` type
- **Separate steps** for Linux (`aws:runShellScript`) and Windows (`aws:runPowerShellScript`)
- **Platform detection** using `platformType` preconditions
- **S3 integration** for downloading installers
- **Parameter-driven configuration** for buckets, paths, CID, etc.

### GCP VM Manager Equivalent
The GCP conversion provides:
- **OS Policy Assignments** (equivalent to SSM Documents)
- **Separate Linux and Windows policies** with OS filtering
- **Shell and PowerShell execution** support
- **Cloud Storage integration** for downloading installers
- **Variable-driven configuration** matching AWS parameters

## Key Differences and Improvements

### 1. OS Detection and Targeting

**AWS (in your original):**
```json
"precondition": {
  "StringEquals": [
    "platformType",
    "Windows"
  ]
}
```

**GCP (in our conversion):**
```terraform
inventory_filters {
  os_short_name = "windows"
}
```

### 2. Script Execution

**AWS Windows (PowerShell):**
```json
"action": "aws:runPowerShellScript"
```

**GCP Windows (PowerShell):**
```terraform
exec {
  enforce {
    interpreter = "POWERSHELL"
    script = templatefile("${path.module}/download-and-run-windows.ps1", {...})
  }
}
```

**AWS Linux (Bash):**
```json
"action": "aws:runShellScript"
```

**GCP Linux (Bash):**
```terraform
exec {
  enforce {
    interpreter = "SHELL"
    script = templatefile("${path.module}/download-and-run.sh", {...})
  }
}
```

### 3. File Downloads

**AWS (S3):**
```powershell
Read-S3Object -BucketName "{{ CrowdStrikeS3BucketName }}" -Key "{{ CrowdStrikeS3Path }}/WindowsSensor.exe"
```

**GCP (Cloud Storage):**
```powershell
gsutil cp "$GcsInstallerPath" "$LocalPath"
```

### 4. Parameter Configuration

**AWS SSM Parameters:**
```json
"CrowdStrikeS3BucketName": {
  "default": "ns2-il5-security-binaries",
  "type": "String"
},
"CrowdStrikeCID": {
  "default": "F58FEA2DE52E40099A58F752AD73A82B-DB",
  "type": "String"
}
```

**GCP Terraform Variables:**
```terraform
variable "gcs_installer_path_windows" {
  description = "GCS path to the CrowdStrike installer for Windows"
  type        = string
}

variable "crowdstrike_cid" {
  description = "CrowdStrike Customer ID (CID) for agent registration"
  type        = string
}
```

## Enhanced Features in GCP Version

### 1. Intelligent OS Package Selection (Linux)
The GCP version automatically selects the appropriate Linux package based on OS detection:
- **Red Hat/CentOS**: `falcon-sensor-el${version}.x86_64.rpm`
- **SUSE**: `falcon-sensor-suse${version}.x86_64.rpm`
- **Ubuntu**: `falcon-sensor-amd64.deb`
- **Amazon Linux**: `falcon-sensor-amzn${version}.x86_64.rpm`

### 2. Flexible Instance Targeting
More advanced targeting options compared to AWS:
```terraform
target_instances = {
  all = false
  include_labels = {
    security-agent = "crowdstrike"
    environment    = "production"
  }
  exclude_labels = {
    crowdstrike-skip = "true"
  }
  zones = ["us-central1-a", "us-central1-b"]
  instance_names = ["specific-server-1", "specific-server-2"]
}
```

### 3. Comprehensive Error Handling
Both scripts include:
- Pre-installation checks (admin rights, existing installation)
- Download verification
- Installation status validation
- Cloud Logging integration
- Cleanup procedures

### 4. Scheduling and Automation
Integrated Cloud Scheduler for automated deployments:
```terraform
schedule = "0 2 * * *"  # Daily at 2 AM
```

## Usage Example

### AWS SSM Document Usage
```bash
aws ssm send-command \
  --document-name "ns2-install-crowdstrike-agent-document" \
  --targets "Key=tag:SecurityAgent,Values=crowdstrike" \
  --parameters CrowdStrikeCID=F58FEA2DE52E40099A58F752AD73A82B-DB
```

### GCP VM Manager Usage
```terraform
module "crowdstrike_agent" {
  source = "./modules/os-manager-crowdstrike"

  project_id  = "your-project-id"
  region      = "us-central1"
  environment = "production"

  crowdstrike_cid = "F58FEA2DE52E40099A58F752AD73A82B-DB"
  
  gcs_installer_path_linux   = "gs://security-binaries/crowdstrike/"
  gcs_installer_path_windows = "gs://security-binaries/crowdstrike/WindowsSensor.exe"
  
  target_instances = {
    include_labels = {
      security-agent = "crowdstrike"
    }
  }
}
```

## File Structure

```
modules/os-manager-crowdstrike/
├── main.tf                           # Main Terraform configuration
├── variables.tf                      # Input variables
├── outputs.tf                        # Output values
├── download-and-run.sh              # Linux installation script
└── download-and-run-windows.ps1     # Windows installation script
```

## Migration Checklist

- [ ] Upload CrowdStrike installers to Cloud Storage bucket
- [ ] Configure service account with necessary permissions
- [ ] Update CrowdStrike CID in variables
- [ ] Configure instance labels for targeting
- [ ] Test with a small subset of instances first
- [ ] Monitor Cloud Logging for installation results

## Required GCP APIs
The module automatically enables:
- OS Config API (`osconfig.googleapis.com`)
- Compute Engine API (`compute.googleapis.com`)
- Cloud Storage API (`storage.googleapis.com`)
- Cloud Scheduler API (`cloudscheduler.googleapis.com`)
- Pub/Sub API (`pubsub.googleapis.com`)

## Permissions Required
The Compute Engine service account needs:
- `roles/storage.objectViewer` (to download from Cloud Storage)
- `roles/logging.logWriter` (for Cloud Logging)
- `roles/osconfig.patchJobExecutor` (for OS Config policies)

This conversion maintains all the functionality of your AWS SSM document while leveraging GCP's native services and providing enhanced targeting and monitoring capabilities.
