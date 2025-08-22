#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------
# setup.sh – scaffold CrowdStrike Terraform configs
# ---------------------------------------------------

echo "🚀 CrowdStrike Agent Deployment Setup"
echo "======================================"
echo

# Loop until user signals they are done
while true; do
  read -p "Enter an account folder name (or press ENTER to finish): " ACCOUNT
  if [[ -z "$ACCOUNT" ]]; then
    echo "Done creating account configs."
    break
  fi

  echo
  echo "Configuring CrowdStrike deployment for account: $ACCOUNT"
  echo "--------------------------------------------------------"

  # Prompt for GCP Project ID
  read -p "Enter GCP Project ID for '${ACCOUNT}': " PROJECT_ID

  # Prompt for GCP Region
  read -p "Enter GCP region for '${ACCOUNT}' (default: us-central1): " REGION
  REGION=${REGION:-us-central1}  # Use default if empty

  # Prompt for environment
  read -p "Enter environment name (dev/staging/prod, default: prod): " ENVIRONMENT
  ENVIRONMENT=${ENVIRONMENT:-prod}

  # Service Account Key (only supported authentication method)
  echo
  echo "🔑 Service Account Authentication"
  echo "Please provide the service account key path in the correct format for your environment:"
  echo "  • Git Bash/MSYS2: /c/Users/username/path/to/key.json"
  echo "  • WSL: /mnt/c/Users/username/path/to/key.json"
  echo "  • Linux/Mac: /home/username/path/to/key.json"
  echo
  read -p "Enter path to service account key JSON file: " SERVICE_ACCOUNT_KEY
  
  # Remove quotes if present
  SERVICE_ACCOUNT_KEY=$(echo "$SERVICE_ACCOUNT_KEY" | sed 's/^"//;s/"$//')
  
  # Simple file existence check
  if [[ ! -f "$SERVICE_ACCOUNT_KEY" ]]; then
    echo "⚠️  Warning: Service account key file not found at: $SERVICE_ACCOUNT_KEY"
    echo "    Please ensure:"
    echo "    - The path is correct and uses the right format for your environment"
    echo "    - The file exists at that location"
    echo "    - You have read permissions for the file"
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
      echo "Skipping account $ACCOUNT"
      continue
    fi
  else
    echo "✅ Service account key file found"
  fi

  # Prompt for state backend configuration
  echo
  echo "🗂️  Terraform State Configuration"
  echo "Choose Terraform state backend:"
  echo "1. Local state (not recommended for production)"
  echo "2. GCS bucket (recommended)"
  read -p "Select option (1-2, default: 2): " STATE_BACKEND
  STATE_BACKEND=${STATE_BACKEND:-2}

  # Handle GCS state backend
  STATE_BUCKET=""
  STATE_PREFIX=""
  if [[ "$STATE_BACKEND" == "2" ]]; then
    read -p "Enter GCS bucket name for Terraform state: " STATE_BUCKET
    read -p "Enter state file prefix (default: terraform-security-agents-state): " STATE_PREFIX
    STATE_PREFIX=${STATE_PREFIX:-terraform-security-agents-state}
  fi

  # CrowdStrike Configuration
  echo
  echo "🛡️  CrowdStrike Configuration"
  read -p "Enter CrowdStrike Customer ID (CID): " CROWDSTRIKE_CID
  
  # Validate CID is not empty
  while [[ -z "$CROWDSTRIKE_CID" ]]; do
    echo "⚠️  CrowdStrike Customer ID cannot be empty!"
    read -p "Enter CrowdStrike Customer ID (CID): " CROWDSTRIKE_CID
  done
  
  read -p "Enter GCS path for Linux installers (e.g., gs://bucket/crowdstrike/): " GCS_LINUX_PATH
  
  # Validate Linux path is not empty
  while [[ -z "$GCS_LINUX_PATH" ]]; do
    echo "⚠️  GCS path for Linux installers cannot be empty!"
    read -p "Enter GCS path for Linux installers (e.g., gs://bucket/crowdstrike/): " GCS_LINUX_PATH
  done
  
  read -p "Enter GCS path for Windows installer (e.g., gs://bucket/crowdstrike/WindowsSensor.exe): " GCS_WINDOWS_PATH
  
  # Validate Windows path is not empty
  while [[ -z "$GCS_WINDOWS_PATH" ]]; do
    echo "⚠️  GCS path for Windows installer cannot be empty!"
    read -p "Enter GCS path for Windows installer (e.g., gs://bucket/crowdstrike/WindowsSensor.exe): " GCS_WINDOWS_PATH
  done
  
  echo "✅ CrowdStrike configuration completed:"
  echo "    CID: $CROWDSTRIKE_CID"
  echo "    Linux installers: $GCS_LINUX_PATH"
  echo "    Windows installer: $GCS_WINDOWS_PATH"
  
  # Schedule configuration
  echo
  echo "⏰ Scheduling Configuration"
  read -p "Enter cron schedule for deployment (default: 0 2 * * * for daily at 2 AM): " SCHEDULE
  SCHEDULE=${SCHEDULE:-"0 2 * * *"}

  # Instance targeting
  echo
  echo "🎯 Instance Targeting"
  echo "Configure which instances should receive CrowdStrike:"
  read -p "Target all instances? (y/N): " TARGET_ALL
  
  INCLUDE_LABELS=""
  EXCLUDE_LABELS=""
  TARGET_ZONES=""
  
  if [[ ! "$TARGET_ALL" =~ ^[Yy]$ ]]; then
    echo "Configure label-based targeting:"
    read -p "Include instances with labels (format: key1=value1,key2=value2 or press ENTER for default): " INCLUDE_LABELS
    read -p "Exclude instances with labels (format: key1=value1,key2=value2 or press ENTER to skip): " EXCLUDE_LABELS
    read -p "Target specific zones (comma-separated, or press ENTER for all zones): " TARGET_ZONES
  fi

  ACCOUNT_DIR="accounts/${ACCOUNT}"
  mkdir -p "${ACCOUNT_DIR}"

  echo
  echo "📝 Generating Terraform configuration..."

  # Write main.tf
  cat > "${ACCOUNT_DIR}/main.tf" <<EOF
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
EOF

  # Add state backend configuration
  if [[ "$STATE_BACKEND" == "2" ]]; then
    cat >> "${ACCOUNT_DIR}/main.tf" <<EOF
  
  backend "gcs" {
    bucket = "${STATE_BUCKET}"
    prefix = "${STATE_PREFIX}"
  }
EOF
  fi

  cat >> "${ACCOUNT_DIR}/main.tf" <<EOF
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.service_account_key_path)
}

module "crowdstrike_agent" {
  source = "../../modules/os-manager-crowdstrike"
  
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  
  # CrowdStrike Configuration
  crowdstrike_cid                = var.crowdstrike_cid
  gcs_installer_path_linux       = var.gcs_installer_path_linux
  gcs_installer_path_windows     = var.gcs_installer_path_windows
  
  # Scheduling
  schedule = var.schedule
  
  # Instance Targeting
  target_instances = var.target_instances
  
  # Additional script arguments (if needed)
  script_args = var.script_args
}
EOF

  # Write variables.tf
  cat > "${ACCOUNT_DIR}/variables.tf" <<EOF
variable "project_id" {
  description = "GCP project ID for this account"
  type        = string
}

variable "region" {
  description = "GCP region (e.g. us-central1)"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "service_account_key_path" {
  description = "Path to the service account key JSON file"
  type        = string
  sensitive   = true
}

# CrowdStrike Configuration Variables
variable "crowdstrike_cid" {
  description = "CrowdStrike Customer ID (CID) for agent registration"
  type        = string
  sensitive   = true
}

variable "gcs_installer_path_linux" {
  description = "GCS path to the CrowdStrike installer directory for Linux (script auto-selects appropriate package)"
  type        = string
}

variable "gcs_installer_path_windows" {
  description = "GCS path to the CrowdStrike installer for Windows"
  type        = string
}

variable "schedule" {
  description = "Cron schedule for CrowdStrike deployment"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

variable "script_args" {
  description = "Additional arguments to pass to the CrowdStrike installation script"
  type        = string
  default     = ""
}

variable "target_instances" {
  description = "Instance targeting configuration for CrowdStrike deployment"
  type = object({
    all = optional(bool, false)
    include_labels = optional(map(string), {})
    exclude_labels = optional(map(string), {})
    zones = optional(list(string), [])
    instance_names = optional(list(string), [])
  })
  default = {
    all = false
    include_labels = {
      security-agent = "crowdstrike"
    }
  }
}
EOF

  # Write terraform.tfvars with user-provided values
  cat > "${ACCOUNT_DIR}/terraform.tfvars" <<EOF
# Project Configuration
project_id  = "${PROJECT_ID}"
region      = "${REGION}"
environment = "${ENVIRONMENT}"

# Authentication
service_account_key_path = "${SERVICE_ACCOUNT_KEY}"

# CrowdStrike Configuration
crowdstrike_cid                = "${CROWDSTRIKE_CID}"
gcs_installer_path_linux       = "${GCS_LINUX_PATH}"
gcs_installer_path_windows     = "${GCS_WINDOWS_PATH}"

# Scheduling
schedule = "${SCHEDULE}"

# Additional script arguments (customize as needed)
script_args = ""
EOF

  # Add target_instances configuration based on user input
  if [[ "$TARGET_ALL" =~ ^[Yy]$ ]]; then
    cat >> "${ACCOUNT_DIR}/terraform.tfvars" <<EOF

# Instance Targeting - Target ALL instances
target_instances = {
  all = true
}
EOF
  else
    # Build the target_instances configuration
    cat >> "${ACCOUNT_DIR}/terraform.tfvars" <<EOF

# Instance Targeting - Label-based targeting
target_instances = {
  all = false
EOF

    # Handle include labels
    if [[ -n "$INCLUDE_LABELS" ]]; then
      echo "  include_labels = {" >> "${ACCOUNT_DIR}/terraform.tfvars"
      IFS=',' read -ra LABELS <<< "$INCLUDE_LABELS"
      for label in "${LABELS[@]}"; do
        if [[ "$label" == *"="* ]]; then
          key="${label%=*}"
          value="${label#*=}"
          echo "    \"$key\" = \"$value\"" >> "${ACCOUNT_DIR}/terraform.tfvars"
        fi
      done
      echo "  }" >> "${ACCOUNT_DIR}/terraform.tfvars"
    else
      cat >> "${ACCOUNT_DIR}/terraform.tfvars" <<EOF
  include_labels = {
    security-agent = "crowdstrike"
  }
EOF
    fi

    # Handle exclude labels
    if [[ -n "$EXCLUDE_LABELS" ]]; then
      echo "  exclude_labels = {" >> "${ACCOUNT_DIR}/terraform.tfvars"
      IFS=',' read -ra LABELS <<< "$EXCLUDE_LABELS"
      for label in "${LABELS[@]}"; do
        if [[ "$label" == *"="* ]]; then
          key="${label%=*}"
          value="${label#*=}"
          echo "    \"$key\" = \"$value\"" >> "${ACCOUNT_DIR}/terraform.tfvars"
        fi
      done
      echo "  }" >> "${ACCOUNT_DIR}/terraform.tfvars"
    else
      echo "  exclude_labels = {}" >> "${ACCOUNT_DIR}/terraform.tfvars"
    fi

    # Handle zones
    if [[ -n "$TARGET_ZONES" ]]; then
      echo "  zones = [" >> "${ACCOUNT_DIR}/terraform.tfvars"
      IFS=',' read -ra ZONES <<< "$TARGET_ZONES"
      for zone in "${ZONES[@]}"; do
        zone=$(echo "$zone" | xargs)  # trim whitespace
        echo "    \"$zone\"," >> "${ACCOUNT_DIR}/terraform.tfvars"
      done
      echo "  ]" >> "${ACCOUNT_DIR}/terraform.tfvars"
    else
      echo "  zones = []" >> "${ACCOUNT_DIR}/terraform.tfvars"
    fi

    echo "}" >> "${ACCOUNT_DIR}/terraform.tfvars"
  fi

  echo "→ Created ${ACCOUNT_DIR} for CrowdStrike deployment"
  
  # Create deployment script
  cat > "${ACCOUNT_DIR}/deploy.sh" <<'DEPLOY_EOF'
#!/usr/bin/env bash
set -euo pipefail

# CrowdStrike deployment script for this account
ACCOUNT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNT_NAME="$(basename "$ACCOUNT_DIR")"

echo "�️  Deploying CrowdStrike agents for account: $ACCOUNT_NAME"
echo "📁 Working directory: $ACCOUNT_DIR"

# Check if service account key exists
if [[ -f terraform.tfvars ]]; then
    SA_KEY_PATH=$(grep "service_account_key_path" terraform.tfvars | cut -d'"' -f2)
    if [[ ! -f "$SA_KEY_PATH" ]]; then
        echo "❌ Service account key file not found: $SA_KEY_PATH"
        echo "Please ensure the service account key file exists."
        exit 1
    fi
    echo "✅ Service account key found: $SA_KEY_PATH"
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning CrowdStrike deployment..."
terraform plan -out=tfplan

# Show what will be deployed
echo
echo "📋 Deployment Summary:"
echo "  • CrowdStrike OS Policy Assignments (Linux & Windows)"
echo "  • Cloud Storage bucket for installation scripts"
echo "  • Cloud Scheduler for automated deployment"
echo "  • Pub/Sub topic for triggering"
echo

# Ask for confirmation
read -p "Do you want to apply this plan? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "🎯 Applying Terraform plan..."
    terraform apply tfplan
    echo "✅ CrowdStrike deployment completed successfully!"
    echo
    echo "📊 You can monitor deployment status in the GCP Console:"
    echo "  • OS Config -> OS Policy Assignments"
    echo "  • Logging -> Logs Explorer (search for 'crowdstrike-install')"
else
    echo "❌ Deployment cancelled."
    rm -f tfplan
fi
DEPLOY_EOF

  chmod +x "${ACCOUNT_DIR}/deploy.sh"
echo "📋 Planning deployment..."
  # Create destroy script
  cat > "${ACCOUNT_DIR}/destroy.sh" <<'DESTROY_EOF'
#!/usr/bin/env bash
set -euo pipefail

# Destroy script for CrowdStrike deployment
ACCOUNT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNT_NAME="$(basename "$ACCOUNT_DIR")"

echo "🗑️  Destroying CrowdStrike agents for account: $ACCOUNT_NAME"
echo "⚠️  This will remove all CrowdStrike infrastructure!"
echo
echo "📋 This will destroy:"
echo "  • CrowdStrike OS Policy Assignments"
echo "  • Cloud Storage bucket and scripts"
echo "  • Cloud Scheduler job"
echo "  • Pub/Sub topic"
echo

# Ask for confirmation
read -p "Are you sure you want to destroy everything? Type 'yes' to confirm: " confirm
if [[ "$confirm" == "yes" ]]; then
    echo "🔧 Initializing Terraform..."
    terraform init
    
    echo "🗑️  Planning destruction..."
    terraform plan -destroy
    
    read -p "Proceed with destruction? (y/N): " final_confirm
    if [[ "$final_confirm" =~ ^[Yy]$ ]]; then
        echo "💥 Destroying CrowdStrike infrastructure..."
        terraform destroy -auto-approve
        echo "✅ Destruction completed!"
    else
        echo "❌ Destruction cancelled."
    fi
else
    echo "❌ Destruction cancelled."
fi
DESTROY_EOF

  chmod +x "${ACCOUNT_DIR}/destroy.sh"

  # Create README for this account
  cat > "${ACCOUNT_DIR}/README.md" <<README_EOF
# CrowdStrike Agent Deployment for Account: ${ACCOUNT}

This directory contains Terraform configuration for deploying CrowdStrike agents to GCP project: \`${PROJECT_ID}\`

## Configuration

- **Project ID**: ${PROJECT_ID}
- **Region**: ${REGION}
- **Environment**: ${ENVIRONMENT}
- **Authentication**: Service Account Key
- **Key Path**: ${SERVICE_ACCOUNT_KEY}
README_EOF

  if [[ "$STATE_BACKEND" == "2" ]]; then
    cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
- **State Backend**: GCS Bucket
- **State Bucket**: ${STATE_BUCKET}
- **State Prefix**: ${STATE_PREFIX}
README_EOF
  else
    cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
- **State Backend**: Local
README_EOF
  fi

  cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF

## CrowdStrike Configuration

- **Customer ID (CID)**: ${CROWDSTRIKE_CID}
- **Linux Installer Path**: ${GCS_LINUX_PATH}
- **Windows Installer Path**: ${GCS_WINDOWS_PATH}
- **Deployment Schedule**: ${SCHEDULE}

## Quick Start

1. **Ensure Prerequisites**:
   - Service account key file exists: \`${SERVICE_ACCOUNT_KEY}\`
   - CrowdStrike installer files are uploaded to Cloud Storage
   - Required GCP APIs are enabled in the project

2. **Deploy CrowdStrike agents**:
   \`\`\`bash
   ./deploy.sh
   \`\`\`

3. **Monitor deployment**:
   - Go to GCP Console → Compute Engine → OS Configuration → OS Policy Assignments
   - Check Cloud Logging for installation logs (search for 'crowdstrike-install')

4. **Destroy deployment** (if needed):
   \`\`\`bash
   ./destroy.sh
   \`\`\`

## Manual Deployment

If you prefer manual control:

\`\`\`bash
# Initialize and validate
terraform init
terraform validate

# Plan and apply
terraform plan
terraform apply

# Destroy (when needed)
terraform destroy
\`\`\`

## Files

- \`main.tf\` - Main Terraform configuration
- \`variables.tf\` - Variable definitions
- \`terraform.tfvars\` - Variable values
- \`deploy.sh\` - Deployment convenience script
- \`destroy.sh\` - Destruction convenience script

## Customization

Edit \`terraform.tfvars\` to update:
- CrowdStrike Customer ID
- GCS installer paths
- Deployment schedule
- Instance targeting rules

## Instance Targeting

README_EOF

  if [[ "$TARGET_ALL" =~ ^[Yy]$ ]]; then
    cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
Currently configured to target **ALL instances** in the project.

⚠️  **Warning**: This will deploy CrowdStrike to every VM instance in the project.
README_EOF
  else
    cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
Currently configured for label-based targeting:
README_EOF
    if [[ -n "$INCLUDE_LABELS" ]]; then
      cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
- **Include instances with labels**: ${INCLUDE_LABELS}
README_EOF
    else
      cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
- **Include instances with labels**: security-agent=crowdstrike (default)
README_EOF
    fi
    
    if [[ -n "$EXCLUDE_LABELS" ]]; then
      cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
- **Exclude instances with labels**: ${EXCLUDE_LABELS}
README_EOF
    fi
    
    if [[ -n "$TARGET_ZONES" ]]; then
      cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF
- **Target zones**: ${TARGET_ZONES}
README_EOF
    fi
  fi

  cat >> "${ACCOUNT_DIR}/README.md" <<README_EOF

## Troubleshooting

1. **Check OS Policy Assignment status**:
   \`\`\`bash
   gcloud compute os-config os-policy-assignments list --project=${PROJECT_ID}
   \`\`\`

2. **View installation logs**:
   \`\`\`bash
   gcloud logging read "resource.type=gce_instance AND textPayload:crowdstrike-install" --project=${PROJECT_ID}
   \`\`\`

3. **Check instance compliance**:
   \`\`\`bash
   gcloud compute os-config os-policy-assignment-reports list --project=${PROJECT_ID}
   \`\`\`
README_EOF

  echo
  echo "✅ Successfully created CrowdStrike deployment configuration!"
  echo "📁 Account directory: ${ACCOUNT_DIR}"
  echo "🚀 Run './deploy.sh' in the account directory to deploy"
  echo

done

echo
echo "🎉 Setup completed! Summary of created accounts:"
for account_dir in accounts/*/; do
  if [[ -d "$account_dir" ]]; then
    account_name=$(basename "$account_dir")
    echo "  📂 $account_name"
  fi
done
echo
echo "💡 Next steps:"
echo "  1. Upload CrowdStrike installers to your Cloud Storage buckets"
echo "  2. Ensure service account keys are accessible"
echo "  3. Run ./deploy.sh in each account directory"
echo "  4. Monitor deployments in GCP Console → OS Configuration"
