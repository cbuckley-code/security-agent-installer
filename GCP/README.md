# GCP Security Agents OS Config Modules

This repository contains Terraform modules for deploying security agents (CrowdStrike, Trend Micro, and Nessus) on GCP instances using OS Config with **smart instance targeting**.

## 🚀 Features

- **🎯 Smart Instance Targeting**: Precise control over which instances receive security agents
- **🔐 GCS Integration**: All installer binaries are downloaded from Google Cloud Storage
- **⏰ Configurable Schedules**: Set custom cron schedules for agent installation
- **🛠️ Custom Arguments**: Pass specific arguments to each security agent installer
- **📦 Multiple File Types**: Supports .deb, .rpm, .run, and .bin installer formats
- **🧹 Automatic Cleanup**: Downloaded installers are cleaned up after installation
- **📊 Cloud Logging**: Installation events are logged to Cloud Logging
- **🏷️ Label-Based Targeting**: Target instances by labels (recommended approach)
- **🌍 Zone-Specific Deployment**: Target specific GCP zones and regions
- **🖥️ OS Filtering**: Deploy only to compatible operating systems
- **🏗️ Account Scaffolding**: Automated setup script for per-account configurations

## 🚀 Quick Start

### 1. Setup Account Configuration
```bash
./setup.sh
```
This interactive script will:
- Prompt you to select which security agent modules to deploy (CrowdStrike, Trend, Nessus, or all)
- Create per-account Terraform configurations
- Generate deployment and cleanup scripts
- Set up GCS backend for Terraform state (optional)

### 2. Upload Security Agent Installers to GCS
```bash
# Create a dedicated bucket for security agent installers
gsutil mb gs://your-security-agents-bucket

# Upload your installer files
gsutil cp falcon-sensor.deb gs://your-security-agents-bucket/crowdstrike/
gsutil cp trend-agent.rpm gs://your-security-agents-bucket/trend/
gsutil cp nessus-agent.deb gs://your-security-agents-bucket/nessus/

# Set appropriate permissions (adjust as needed for your security requirements)
gsutil iam ch serviceAccount:your-osconfig-sa@project.iam.gserviceaccount.com:objectViewer gs://your-security-agents-bucket
```

### 3. Label Your Target Instances
**This is the recommended approach for targeting instances.**

```bash
# Label instances for CrowdStrike deployment
gcloud compute instances add-labels web-server-1 \
  --labels="security-agent=crowdstrike,environment=production,role=webserver"

# Label instances for Trend Micro deployment
gcloud compute instances add-labels database-server \
  --labels="security-agent=trend,environment=production,role=database"

# Label instances for multiple agents (if needed)
gcloud compute instances add-labels monitoring-server \
  --labels="security-agent=nessus,environment=production,role=monitoring"
```

### 4. Configure Your Variables
Edit the generated `terraform.tfvars` file in your account folder:

```hcl
# Project Configuration
project_id = "your-gcp-project-id"
region     = "us-central1"

# CrowdStrike Configuration
os_manager_crowdstrike_gcs_installer_path = "gs://your-security-agents-bucket/crowdstrike/falcon-sensor.deb"
os_manager_crowdstrike_script_args        = "--cid=YOUR_CROWDSTRIKE_CID_HERE"
os_manager_crowdstrike_schedule           = "0 2 * * *"  # Daily at 2 AM

# Target only production instances labeled for CrowdStrike
os_manager_crowdstrike_target_instances = {
  include_labels = {
    security-agent = "crowdstrike"
    environment    = "production"
  }
  exclude_labels = {
    maintenance = "true"  # Exclude instances under maintenance
  }
}

# Only deploy to Ubuntu 20.04 instances
os_manager_crowdstrike_os_filter = {
  os_short_name = "ubuntu"
  os_version    = "20.04"
}

# Trend Micro Configuration (if selected)
os_manager_trend_gcs_installer_path = "gs://your-security-agents-bucket/trend/agent.rpm"
os_manager_trend_script_args        = "--manager=https://your-dsm.example.com:4120/"
os_manager_trend_schedule           = "0 3 * * *"  # Daily at 3 AM

os_manager_trend_target_instances = {
  include_labels = {
    security-agent = "trend"
    environment    = "production"
  }
}

os_manager_trend_os_filter = {
  os_short_name = "centos"
}

# Nessus Configuration (if selected)
os_manager_nessus_gcs_installer_path = "gs://your-security-agents-bucket/nessus/NessusAgent.deb"
os_manager_nessus_script_args        = "--key=YOUR_NESSUS_LINKING_KEY --server=your-nessus-server.example.com --port=8834"
os_manager_nessus_schedule           = "0 1 * * 0"  # Weekly on Sunday at 1 AM

os_manager_nessus_target_instances = {
  include_labels = {
    security-agent = "nessus"
    environment    = "production"
  }
  zones = ["us-central1-a", "us-central1-b"]  # Limit to specific zones
}

os_manager_nessus_os_filter = {
  os_short_name = "ubuntu"
  os_version    = "20.04"
}
```

### 5. Deploy the Security Agents
```bash
cd accounts/your-account
chmod +x deploy.sh
./deploy.sh
```

This will run:
1. `terraform init` (with GCS backend if configured)
2. `terraform plan` (review the changes)
3. `terraform apply` (deploy the configuration)

## 🎯 Instance Targeting Guide

### **Targeting Methods** (in order of recommendation)

#### 1. **🏷️ Label-Based Targeting (Highly Recommended)**
Use GCP instance labels for flexible and maintainable targeting:

```hcl
target_instances = {
  include_labels = {
    security-agent = "crowdstrike"      # Must have this label
    environment    = "production"       # AND this label
    team          = "backend"           # AND this label
  }
  exclude_labels = {
    role         = "database"           # EXCLUDE if has this label
    environment  = "development"        # OR this label
    maintenance  = "true"               # OR this label
  }
}
```

**Benefits:**
- Easy to manage at scale
- Self-documenting instance purposes
- Can be automated with CI/CD pipelines
- Supports complex targeting logic

#### 2. **🌍 Zone-Specific Targeting**
Target instances in specific zones (useful for regional rollouts):

```hcl
target_instances = {
  zones = ["us-central1-a", "us-central1-b"]
  include_labels = {
    environment = "production"
  }
}
```

#### 3. **📝 Instance Name Targeting**
Target specific instances by name (useful for testing):

```hcl
target_instances = {
  instance_names = [
    "web-server-1",
    "web-server-2", 
    "api-server-prod-001"
  ]
}
```

#### 4. **⚠️ All Instances (Use with Extreme Caution)**
```hcl
target_instances = {
  all = true  # ⚠️ This will target ALL instances in the project!
}
```

### **🖥️ Operating System Filtering**
Ensure agents are only deployed to compatible operating systems:

```hcl
# Ubuntu 20.04 only
os_filter = {
  os_short_name = "ubuntu"
  os_version    = "20.04"
}

# Any CentOS version
os_filter = {
  os_short_name = "centos"
}

# RHEL 8.x
os_filter = {
  os_short_name = "rhel"
  os_version    = "8"
}
```

**Supported OS short names:** `ubuntu`, `centos`, `rhel`, `debian`, `sles`, `windows`

### **📋 Targeting Best Practices**

1. **Start Small**: Test with a single instance or small zone first
2. **Use Labels**: Label-based targeting is the most maintainable approach
3. **Layer Filters**: Combine labels, zones, and OS filters for precise control
4. **Document Labels**: Maintain a labeling convention and document it
5. **Monitor Deployments**: Use Cloud Logging to monitor installation progress
## 🔧 Module Configuration Reference

### Common Variables (All Modules)

| Variable | Type | Description | Required | Default |
|----------|------|-------------|----------|---------|
| `project_id` | string | GCP project ID | ✅ | - |
| `region` | string | GCP region | ✅ | - |
| `gcs_installer_path` | string | GCS path to installer (e.g., `gs://bucket/path/installer.deb`) | ✅ | - |
| `schedule` | string | Cron schedule for execution | ❌ | `"0 2 * * *"` |
| `script_args` | string | Arguments to pass to the installer | ❌ | `""` |
| `target_instances` | object | Instance targeting configuration | ❌ | `{}` |
| `os_filter` | object | Operating system filtering | ❌ | `{}` |

### Module-Specific Examples

#### 🛡️ CrowdStrike (os-manager-crowdstrike)
```hcl
module "crowdstrike" {
  source = "../../modules/os-manager-crowdstrike"
  
  # Required
  project_id         = "my-gcp-project"
  region             = "us-central1"
  gcs_installer_path = "gs://my-security-bucket/crowdstrike/falcon-sensor.deb"
  script_args        = "--cid=ABC123DEF456GHI789JKL012MNO345PQR678"
  
  # Optional
  schedule = "0 2 * * *"  # Daily at 2 AM
  
  target_instances = {
    include_labels = {
      security-agent = "crowdstrike"
      environment    = "production"
    }
    exclude_labels = {
      role = "database"  # CrowdStrike might interfere with DB performance
    }
  }
  
  os_filter = {
    os_short_name = "ubuntu"
    os_version    = "20.04"
  }
}
```

**CrowdStrike Installation Notes:**
- Requires a valid CID (Customer ID) in `script_args`
- Supports .deb (Ubuntu/Debian) and .rpm (RHEL/CentOS) packages
- May require specific network connectivity for cloud console communication

#### 🔒 Trend Micro (os-manager-trend)
```hcl
module "trend" {
  source = "../../modules/os-manager-trend"
  
  # Required
  project_id         = "my-gcp-project"
  region             = "us-central1"
  gcs_installer_path = "gs://my-security-bucket/trend/agent.rpm"
  script_args        = "--manager=https://your-dsm.example.com:4120/ --tenant=your-tenant-id"
  
  # Optional
  schedule = "0 3 * * *"  # Daily at 3 AM (offset from CrowdStrike)
  
  target_instances = {
    include_labels = {
      security-agent = "trend"
      environment    = "production"
    }
    zones = ["us-central1-a", "us-central1-b"]  # Gradual rollout
  }
  
  os_filter = {
    os_short_name = "centos"
  }
}
```

**Trend Micro Installation Notes:**
- Requires Deep Security Manager (DSM) connection details
- Supports multi-tenancy configurations
- May require tenant ID and policy group specifications

#### 🔍 Nessus (os-manager-nessus)
```hcl
module "nessus" {
  source = "../../modules/os-manager-nessus"
  
  # Required
  project_id         = "my-gcp-project"
  region             = "us-central1"
  gcs_installer_path = "gs://my-security-bucket/nessus/NessusAgent-8.3.1-ubuntu1110_amd64.deb"
  script_args        = "--key=abc123def456ghi789jkl012mno345pqr678stu901vwx234yz --server=nessus-manager.example.com --port=8834"
  
  # Optional
  schedule = "0 1 * * 0"  # Weekly on Sunday at 1 AM
  
  target_instances = {
    include_labels = {
      security-agent = "nessus"
      environment    = "production"
      scan-required  = "true"
    }
  }
  
  os_filter = {
    os_short_name = "ubuntu"
    os_version    = "20.04"
  }
}
```

**Nessus Installation Notes:**
- Requires a linking key and Nessus Manager server details
- Typically installed less frequently (weekly/monthly)
- May require specific firewall rules for manager communication
```hcl
module "nessus" {## 📁 Project Structure

```
GCP/
├── 📄 setup.sh                        # Interactive account configuration script
├── 📄 state-setup.md                  # Guide for Terraform state management
├── 📄 README.md                       # This documentation
├── 📁 accounts/                       # Per-account Terraform configurations
│   └── 📁 your-account/               # Generated account-specific folder
│       ├── 📄 main.tf                 # Main Terraform configuration
│       ├── 📄 variables.tf            # Variable definitions
│       ├── 📄 terraform.tfvars        # Variable values (customize this!)
│       ├── 📄 deploy.sh               # Deployment script
│       ├── 📄 destroy.sh              # Cleanup script
│       └── 📄 README.md               # Account-specific documentation
└── 📁 modules/                        # Reusable Terraform modules
    ├── 📁 os-manager-crowdstrike/      # CrowdStrike Falcon module
    │   ├── 📄 main.tf                  # Module logic and OS Config resources
    │   ├── 📄 variables.tf             # Module input variables
    │   ├── 📄 outputs.tf               # Module outputs
    │   └── 📄 download-and-run.sh      # Installation script
    ├── 📁 os-manager-trend/            # Trend Micro Deep Security module
    │   ├── 📄 main.tf
    │   ├── 📄 variables.tf
    │   ├── 📄 outputs.tf
    │   └── 📄 download-and-run.sh
    └── 📁 os-manager-nessus/           # Nessus Agent module
        ├── 📄 main.tf
        ├── 📄 variables.tf
        ├── 📄 outputs.tf
        └── 📄 download-and-run.sh
```

## ⏰ Schedule Configuration Examples

Use cron syntax to control when agents are installed:

| Schedule | Description | Use Case |
|----------|-------------|----------|
| `"0 2 * * *"` | Daily at 2 AM | Regular security agent updates |
| `"0 */4 * * *"` | Every 4 hours | Frequent compliance checks |
| `"0 1 * * 0"` | Weekly on Sunday at 1 AM | Weekly vulnerability scans |
| `"0 6 1 * *"` | Monthly on the 1st at 6 AM | Monthly security reviews |
| `"0 3 * * 1-5"` | Weekdays at 3 AM | Business hours avoidance |
| `"0 22 * * 6"` | Saturdays at 10 PM | Weekend maintenance windows |

**Schedule Best Practices:**
- Stagger different agent schedules to avoid resource conflicts
- Consider time zones and business hours
- Use less frequent schedules for resource-intensive agents
- Monitor system performance during scheduled installations

## 🔐 Security Considerations

### GCS Bucket Security
```bash
# Create a dedicated bucket with versioning
gsutil mb gs://your-security-agents-bucket
gsutil versioning set on gs://your-security-agents-bucket

# Set bucket-level IAM (restrict access)
gsutil iam ch serviceAccount:os-config-sa@your-project.iam.gserviceaccount.com:objectViewer gs://your-security-agents-bucket
gsutil iam ch user:security-admin@yourcompany.com:admin gs://your-security-agents-bucket

# Set object lifecycle for automatic cleanup of old versions
gsutil lifecycle set lifecycle.json gs://your-security-agents-bucket
```

### Service Account Best Practices
- Use dedicated service accounts for OS Config
- Follow principle of least privilege
- Regularly audit service account permissions
- Consider using Workload Identity where applicable

### Installer Security
- Verify installer checksums before upload
- Use signed installers when available
- Implement approval workflows for installer updates
- Monitor installer access logs

### Network Security
- Ensure agents can reach their management servers
- Configure firewall rules for agent communication
- Use private Google Access for GCS downloads
- Monitor network traffic for anomalies

## 🏗️ Prerequisites & Setup

### Required GCP APIs
Enable these APIs in your project:
```bash
gcloud services enable osconfig.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage-component.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable logging.googleapis.com
```

### Required Permissions
Your deployment account needs these IAM roles:
- `roles/osconfig.patchJobRunner`
- `roles/compute.osAdminLogin` (for OS Config)
- `roles/storage.objectViewer` (for GCS bucket)
- `roles/cloudscheduler.admin`
- `roles/pubsub.admin`
- `roles/logging.logWriter`

### Terraform Requirements
- Terraform >= 1.0.0
- Google Cloud Provider >= 4.0.0

## 🚨 Troubleshooting Guide

### Common Issues

#### ❌ **Installation Failures**
**Symptoms:** OS Config patch job fails, no agent installed
**Solutions:**
1. Check Cloud Logging for detailed error messages:
   ```bash
   gcloud logging read "resource.type=gce_instance AND jsonPayload.message:security-agent" --limit=50
   ```
2. Verify GCS file permissions and accessibility
3. Check if the installer is compatible with the target OS
4. Validate installer arguments format

#### ❌ **GCS Access Issues**
**Symptoms:** "Permission denied" or "File not found" errors
**Solutions:**
1. Verify service account has Storage Object Viewer role
2. Check GCS bucket and object permissions
3. Ensure the GCS path is correct and accessible
4. Test manual download from a target instance

#### ❌ **Schedule Not Triggering**
**Symptoms:** OS Config jobs not running on schedule
**Solutions:**
1. Check Cloud Scheduler configuration in the GCP Console
2. Verify cron syntax is correct
3. Check if the schedule conflicts with other jobs
4. Review Pub/Sub topic permissions

#### ❌ **Targeting Issues**
**Symptoms:** Wrong instances receiving agents, or no instances targeted
**Solutions:**
1. Verify instance labels match targeting configuration
2. Check OS filter compatibility
3. Test targeting logic with a smaller scope first
4. Review instance zones and regional restrictions

### Debug Commands

```bash
# Check OS Config patch jobs
gcloud compute os-config patch-jobs list

# View specific patch job details
gcloud compute os-config patch-jobs describe PATCH_JOB_ID

# Check instance OS details
gcloud compute instances os-inventory list-instances

# Verify instance labels
gcloud compute instances describe INSTANCE_NAME --zone=ZONE

# Test GCS access from instance
gsutil ls gs://your-security-agents-bucket/
```

## 🤝 Contributing

### Adding New Security Agent Modules

1. **Copy Module Structure**:
   ```bash
   cp -r modules/os-manager-crowdstrike modules/os-manager-newagent
   ```

2. **Update Module Files**:
   - Modify `download-and-run.sh` for your agent's installation process
   - Update `variables.tf` with agent-specific variables and descriptions
   - Adjust `main.tf` resource names and descriptions
   - Update `outputs.tf` if needed

3. **Update Setup Script**:
   - Add your module to the selection menu in `setup.sh`
   - Include appropriate variable definitions in the generated configs

4. **Test Your Module**:
   - Test with a single instance first
   - Verify all targeting options work correctly
   - Check Cloud Logging for proper installation reporting

### Code Standards
- Use descriptive variable names and comments
- Follow Terraform best practices
- Include proper error handling in scripts
- Add comprehensive documentation

### Submitting Changes
- Test changes in a development environment
- Update documentation for any new features
- Follow existing code formatting and structure
- Include examples for new configuration options

---

## 📞 Support

For issues and questions:
1. Check the troubleshooting guide above
2. Review Cloud Logging for error details
3. Verify all prerequisites are met
4. Test with minimal configuration first

**Remember**: Start small, test thoroughly, and scale gradually! 🚀
