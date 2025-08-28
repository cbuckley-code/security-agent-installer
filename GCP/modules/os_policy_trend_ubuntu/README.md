# Trend Micro Agent (Cloud One Workload Security) – Terraform Module

Opinionated Terraform module that **deploys a Trend Micro Cloud One Workload Security (a.k.a. Deep Security) agent (`ds_agent`)** to Ubuntu VMs on Google Compute Engine using **OS Config OSPolicy Assignments**. It installs the agent, activates it with your **Activation Key (CID/tenant)**, and ensures the service is running.

> If your environment uses a manager URL + activation key or an installation token flow, this module supports both.


## What this module does

- Creates a **`google_os_config_os_policy_assignment`** targeting the instances you specify (by labels and/or zones).
- Installs the **Trend Micro `ds_agent`** on Ubuntu via ExecStep (shell script).
- **Activates** the agent using your **Activation Key** and optional **Manager URL/Region**.
- Starts/enables the service and verifies status.
- Supports controlled rollout (surge %, min wait) to avoid disruption.

> This module does **not** manage your Trend tenant, policies, or exclusions. It just lays down and activates the agent on targeted VMs.


## Requirements

- Terraform ≥ 1.5
- Google provider ≥ 5.x
- Target VMs are **GCE instances** running **Ubuntu 18.04/20.04/22.04/24.04** (adjust if you have others).
- Instances have the **guest agents** enabled (standard GCE images do).

### GCP APIs to enable (project-level)
- **OS Config API**: `osconfig.googleapis.com`
- **Compute Engine API**: `compute.googleapis.com`
- (Recommended for logs) **Cloud Logging API**: `logging.googleapis.com`

### Permissions / Roles for the deployer (who runs Terraform)

Grant on the target project(s):
- `roles/osconfig.admin` (create/manage OSPolicy Assignments)
- `roles/compute.viewer` (instance filtering by labels/zones)
- `roles/iam.serviceAccountUser` if your pipeline impersonates a SA

> If you can’t get `roles/osconfig.admin`, the exact granular role is fine as long as it includes **`osconfig.osPolicyAssignments.create/update/get/list/delete`**.


## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `project_id` | string | yes | — | GCP project where the assignment lives. |
| `assignment_name` | string | yes | — | OSPolicy Assignment name (must be unique per project/zone). |
| `zones` | list(string) | yes | — | Zones to apply the assignment in (OSPolicy Assignments are zonal). |
| `instance_label_filter` | map(string) | no | `{}` | Match instances by labels (all pairs must match). If empty, applies to **all** instances in the zone(s) — not recommended. |
| `activation_key` | string | conditionally | — | Trend Cloud One **Activation Key** (recommended path). Store securely (TF var / Secret Manager). |
| `manager_url` | string | no | auto | Manager base URL (e.g., `https://workload.us-1.cloudone.trendmicro.com`). If omitted, the install script’s default/region is used. |
| `policy_id` | string | no | — | Optional policy to assign on activation (if your tenant requires it). |
| `tags` | list(string) | no | `[]` | Optional agent tags to register on activation. |
| `rollout_percent` | number | no | `10` | Disruption budget percentage per zone. |
| `min_wait_duration` | string | no | `"600s"` | Min wait between waves (RFC3339 duration). |
| `script_url` | string | no | module default | Override the install script URL if your org mirrors Trend scripts. |
| `extra_args` | list(string) | no | `[]` | Additional args passed to the Trend install script. |

> **Do not** hardcode secrets in `.tf` files. Use `-var`, `*.tfvars`, or Secret Manager with a data source.


## Outputs

| Name | Description |
|------|-------------|
| `assignment_id` | The OSPolicy Assignment ID. |
| `assignment_self_link` | Resource self link. |


## Usage (Quickstart)

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

module "trend_policy" {
  source = "./modules/trend_policy" # or your registry/Git URL

  project_id          = var.project_id
  assignment_name     = "trend-ds-agent-ubuntu"
  zones               = ["us-central1-a", "us-central1-b"]

  # Only target instances with these labels:
  instance_label_filter = {
    os   = "ubuntu"
    env  = "prod"
  }

  # Trend activation
  activation_key = var.trend_activation_key
  manager_url    = "https://workload.us-1.cloudone.trendmicro.com" # optional
  policy_id      = null
  tags           = ["gcp", "prod"]

  # Rollout safety
  rollout_percent    = 10
  min_wait_duration  = "600s"
}
```

**`terraform.tfvars` example**
```hcl
project_id            = "my-prod-project"
trend_activation_key  = "***************" # store securely
```

**Variable definitions**
```hcl
variable "project_id"           { type = string }
variable "trend_activation_key" { type = string, sensitive = true }
```

**Init & apply**
```bash
terraform init
terraform plan -out plan.tfplan
terraform apply plan.tfplan
```


## How it works (under the hood)

- Builds a zonal **OSPolicy Assignment** with a policy that runs an **install shell script** on Ubuntu targets.
- The script downloads and installs `ds_agent`, then **activates** using your `activation_key` (and optional `manager_url`, `policy_id`, `tags`).
- On success, service `ds_agent` is running and the host appears in your **Cloud One Workload Security** console.


## Verifying on a VM

SSH to a targeted instance and run:
```bash
sudo systemctl status ds_agent || systemctl status ds_agent
sudo /opt/ds_agent/dsa_control -m
sudo /opt/ds_agent/dsa_control -V
tail -n 200 /var/log/dsa/agent.log 2>/dev/null || sudo journalctl -u ds_agent -n 200
```

If you see **HTTP 403 – activate agent first**, your activation params were missing/invalid. Re-run the assignment after fixing inputs.


## Common pitfalls & blunt truths

- **409 “Requested entity already exists”**: OSPolicy Assignment names must be **unique per zone**. Change `assignment_name` or destroy the old one before creating a new one.
- **Blank targets**: If you don’t set a label filter, you’ll hit **every** instance in the zone. Don’t be that person in prod.
- **Egress blocked**: The install script needs outbound access to Trend Micro endpoints (or to your internal mirror). If your egress is locked down, **mirror the script & packages** and set `script_url`.
- **Kernel / OS drift**: Keep your base images current. Old kernels + old `ds_agent` = pain.
- **Secrets in git**: Never commit activation keys. Use TF variables, environment variables, or Secret Manager. Full stop.


## Uninstall / Destroy

- **Terraform destroy** removes the Assignment; it does **not** necessarily remove agents already installed. If you need removal, add an **uninstall recipe** or run a one-time cleanup job.
- Manual uninstall on Ubuntu (example, version-specific):
  ```bash
  sudo /opt/ds_agent/dsa_control -x
  sudo apt-get remove -y ds_agent || sudo dpkg -r ds_agent
  sudo rm -rf /opt/ds_agent
  ```


## Versioning

This module tracks GCP provider 5.x and Ubuntu LTS. If you’re on non-Ubuntu distros, you’ll need to extend the OSPolicy recipes (PRs welcome).


## Inputs reference – install script arguments (if you override)

If you supply your own `script_url`, ensure it supports flags like:
- `-a <activation_key>`
- `-m <manager_url>` (Cloud One region manager)
- `-p <policy_id>`
- `--tags <comma,separated,tags>`

Otherwise, adapt the module template to your org’s script.


## Support

Open an issue or ping the maintainer with:
- Project ID, assignment name, zone
- Install logs from `/var/log/dsa/agent.log` (redact keys)
- Output from `systemctl status ds_agent` and `dsa_control -m`

