# OS Policies for GCE — Terraform

Fast path to manage **OS Policy Assignments** (CrowdStrike, Trend, Nessus, etc.) on **Google Compute Engine** via Terraform.

## Prereqs
- **Terraform** ≥ 1.5, **gcloud CLI**, Google provider ≥ 5.28
- A **GCP project** (OS Policy Assignments are **zonal**, pass a zone in `location`)
- A **Terraform Service Account (SA)** to run plan/apply

### Enable APIs
```bash
gcloud services enable osconfig.googleapis.com compute.googleapis.com
# Optional (observability):
gcloud services enable logging.googleapis.com monitoring.googleapis.com
```

### Terraform SA — minimum roles
- Project-level:  
  - `roles/osconfig.admin` (manage OSPolicyAssignments)  
  - `roles/compute.viewer` (labels/inventory filtering)  
  - `roles/iam.serviceAccountUser` **only if** impersonating another SA
- **State bucket**: `roles/storage.objectAdmin` on the bucket (or equivalent object perms)

> Don’t grant Owner. If plan/apply fails, you’re missing one of the above.

## Terraform State (GCS)
- Bucket must exist **before** `terraform init`
- Recommended: **Uniform access**, **Versioning enabled**
- Backend example:
```hcl
backend "gcs" {
  bucket = "<STATE_BUCKET>"
  prefix = "<STATE_PREFIX>"
}
```

## Auth (pick one)
**A) SA Impersonation (recommended, keyless)**
```bash
gcloud auth login
gcloud config set project <PROJECT_ID>
gcloud auth application-default login  # ADC for Terraform
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="tf-runner@<PROJECT_ID>.iam.gserviceaccount.com"
```
Your user needs `roles/iam.serviceAccountTokenCreator` on the impersonated SA.

**B) SA Key File (not recommended)**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa-key.json"
```

## Run Terraform
```bash
terraform init   -backend-config="bucket=<STATE_BUCKET>"   -backend-config="prefix=<STATE_PREFIX>"
terraform plan
terraform apply
```

## Important Variables
- `project_id` — target GCP project
- `location` — **zone** (e.g., `us-central1-a`)
- `label_key` / `label_value` — which instances to target
- Module artifact inputs: `bucket`, `object`, `object_generation`
- Product creds (e.g., `falcon_cid`, `tenable_linking_key`, etc.) — pass via tfvars/env; **never** commit

## Troubleshooting (quick)
- **409 “exists”**: import it or change `assignment_name`  
  ```bash
  terraform import 'module.MOD.google_os_config_os_policy_assignment.NAME'   'projects/PRJ/locations/ZONE/osPolicyAssignments/ASSIGNMENT_NAME'
  ```
- **No targets hit**: label mismatch — verify instance labels
- **Agent not linking / RFM**: fix egress, artifact version, product flags; check service status/logs

Keep the SA minimal, the bucket versioned, and prefer impersonation over keys.


## Module Overview

### `agent_artifacts` (Artifacts Management)
**Purpose:** Manage a **GCS bucket** for agent packages and upload versioned artifacts (e.g., Falcon `.deb`, Trend `ds_agent` packages, Nessus `.deb`). Exposes outputs that the OS Policy modules consume via **remote state**.  It also manages what Service Accounts can access the bucket.
**Key Inputs:**
- Bucket: `project_id`, `bucket_name` (optional), `location` (region), `uniform_access` (bool), `versioning` (bool), `retention_days` (opt), `force_destroy` (opt)
- Artifacts map (path ➜ file):  
  ```hcl
  artifacts = {
    "crowdstrike/falcon-sensor_7.x.y_amd64.deb" = {
      local_path    = "${path.root}/dist/falcon-sensor_7.x.y_amd64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }
    "trend/ds_agent_ubuntu22_x.y.z_amd64.deb" = {
      local_path    = "${path.root}/dist/ds_agent_ubuntu22_x.y.z_amd64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }
    "tenable/NessusAgent-10.9.0-ubuntu1604_amd64.deb" = {
      local_path    = "${path.root}/dist/NessusAgent-10.9.0-ubuntu1604_amd64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }
  }
  ```
**Outputs:**  
- `bucket_name` — the artifacts bucket  
- `object_generations` — map of **object name ➜ generation** (used to pin exact binaries)
**IAM Notes:**  
- **Terraform SA:** `roles/storage.admin` (create/configure bucket + write objects), or at minimum `roles/storage.objectAdmin` if the bucket already exists.  
- **Instance SA (OS Policy install step):** needs `storage.objects.get` on the bucket/object (e.g., `roles/storage.objectViewer`) so VMs can fetch artifacts during install.

---

### `os_policy_falcon_ubuntu`
**Purpose:** Install & configure **CrowdStrike Falcon** sensor on Ubuntu (set CID/token, enable service, validate).  
**Key Inputs:**  
- Targeting: `label_key`, `label_value`  
- Artifact: `bucket`, `object`, `object_generation`  
- Config: `falcon_cid`, `provisioning_token` (optional)  
- Scope/Rollout: `project_id`, `location` (zone), `assignment_name`, `rollout_percent`, `min_wait_duration`  
**Outputs:** `assignment_id`, `assignment_name`, `revision_id`, `rollout_state`, `uid`  
**Verify:**  
```bash
systemctl status falcon-sensor
sudo /opt/CrowdStrike/falconctl -g --cid
```

---

### `os_policy_trend_ubuntu`
**Purpose:** Install & activate **Trend Micro Cloud One Workload Security (ds_agent)** on Ubuntu; start & validate service.  
**Key Inputs:**  
- Targeting: `label_key`, `label_value`  
- Artifact: `bucket`, `ubuntu20_object`, `ubuntu20_object_generation`, `ubuntu22_object`, `ubuntu22_object_generation`  
- Config: `dsm_url`, `tenant_id`, `token`, `group` (opt), `policy_id` (opt)  
- Scope/Rollout: `project_id`, `location`, `assignment_name`, `rollout_percent`, `min_wait_duration`  
**Outputs:** `assignment_id`, `assignment_name`, `revision_id`, `rollout_state`, `uid`  
**Verify:**  
```bash
systemctl status ds_agent
sudo /opt/ds_agent/dsa_control -m
```

---

### `os_policy_nessus_ubuntu`
**Purpose:** Install **Tenable Nessus Agent** from a single multi-Ubuntu `.deb`, link to Tenable (io/on-prem), ensure service, re-link if needed.  
**Key Inputs:**  
- Targeting: `label_key`, `label_value`  
- Artifact: `bucket`, `object`, `object_generation`  
- Config: `tenable_linking_key`, `tenable_host` (default `cloud.tenable.com`), `tenable_port` (443), `tenable_groups` (opt), `agent_name` (opt)  
- Scope/Rollout: `project_id`, `location`, `assignment_name`, `rollout_percent`, `min_wait_duration`  
**Outputs:** `assignment_id`, `assignment_name`, `revision_id`, `rollout_state`, `uid`  
**Verify:**  
```bash
systemctl status nessus-agent
/opt/nessus_agent/sbin/nessuscli agent status
```

---

### Common Pattern (All Modules)
- **Zonal resources:** `location` must be a **zone** (e.g., `us-central1-a`).  
- **Label targeting:** single `label_key`/`label_value` + Ubuntu inventory filter.  
- **Artifacts from GCS:** pass `bucket`/`object`/`object_generation` (often resolved from artifacts remote state).  
- **Rollout safety:** `rollout_percent` and `min_wait_duration` throttle waves.  
- **State gotcha:** If an assignment already exists, **import** it instead of fighting `409 already exists`.

### Examples
There are concrete examples that have been tested in the dev-mtcdo-lab project located in /GCP/examples.  There is an example artifact management project to upload your agents and control
access to the bucket and a project scoped example that installs the agents on Gardener cluster nodes.



