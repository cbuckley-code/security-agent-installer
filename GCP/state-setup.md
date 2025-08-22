# State Management Setup Guide

This guide helps you set up proper Terraform state management for your security agents deployment.

## Recommended Setup for Production

### 1. Create GCS Buckets for Terraform State

Each GCP project or organization should have a dedicated bucket for Terraform state:

```bash
# Create a state bucket (replace with your naming convention)
gsutil mb gs://your-org-terraform-state

# Enable versioning for state file history
gsutil versioning set on gs://your-org-terraform-state

# Set up proper access controls
gsutil iam ch user:terraform-service-account@your-project.iam.gserviceaccount.com:objectAdmin gs://your-org-terraform-state
```

### 2. Service Account Setup

Create a service account for each account/project with minimal required permissions:

```bash
# Create service account
gcloud iam service-accounts create terraform-security-agents \
    --description="Terraform service account for security agents" \
    --display-name="Terraform Security Agents"

# Grant necessary roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-security-agents@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-security-agents@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-security-agents@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudscheduler.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-security-agents@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/pubsub.admin"

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
    --iam-account=terraform-security-agents@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### 3. Directory Structure

```
GCP/
├── setup.sh
├── state-setup.md (this file)
├── modules/
│   ├── os-manager-crowdstrike/
│   ├── os-manager-trend/
│   └── os-manager-nessus/
└── accounts/
    ├── production/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   ├── deploy.sh
    │   ├── destroy.sh
    │   └── README.md
    ├── staging/
    │   └── ...
    └── development/
        └── ...
```

## Authentication Methods

### Option 1: Service Account Key (Recommended for CI/CD)

```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/terraform-key.json"

# Or configure in terraform.tfvars
service_account_key_path = "/path/to/terraform-key.json"
```

### Option 2: Application Default Credentials (Recommended for local development)

```bash
gcloud auth application-default login
```

### Option 3: Workload Identity (Recommended for Google Cloud CI/CD)

Configure Workload Identity for your CI/CD pipeline to assume the Terraform service account.

## State Backend Examples

### GCS Backend (Recommended)

```hcl
terraform {
  backend "gcs" {
    bucket = "your-org-terraform-state"
    prefix = "security-agents/production"
  }
}
```

### Local Backend (Development only)

```hcl
terraform {
  # No backend configuration = local state
}
```

## Security Best Practices

1. **Separate State per Environment**: Use different state prefixes or buckets for prod/staging/dev
2. **Restrict Access**: Only grant necessary permissions to service accounts
3. **Enable State Locking**: GCS automatically provides state locking
4. **Version Control**: Keep state buckets versioned for rollback capability
5. **Encryption**: GCS encrypts state files at rest by default
6. **Audit Logging**: Enable Cloud Audit Logs for state bucket access

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Security Agents
on:
  push:
    branches: [main]
    paths: ['GCP/accounts/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
          
      - name: Deploy
        run: |
          cd GCP/accounts/production
          terraform init
          terraform plan
          terraform apply -auto-approve
```

## Troubleshooting

### State Lock Issues
```bash
# Force unlock if state is stuck (use carefully!)
terraform force-unlock LOCK_ID
```

### State Migration
```bash
# Migrate from local to GCS
terraform init -migrate-state
```

### State Inspection
```bash
# View current state
terraform state list
terraform state show <resource>
```
