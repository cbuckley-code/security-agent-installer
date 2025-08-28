# agents_artifacts (GCS)

Creates or reuses a **GCS bucket**, uploads agent artifacts (e.g., CrowdStrike Falcon `.deb`), and grants read access to **service accounts** (node SAs). Outputs **generations** for pinning in OS Policies.

## Inputs
- `project_id` (string) – Project owning the bucket/objects.
- `bucket_name` (string) – Bucket name to create or reuse.
- `create_bucket` (bool, default `true`) – Create the bucket or reuse existing.
- `bucket_location` (string, default `US`) – Bucket location (region or multi-region).
- `storage_class` (string, default `STANDARD`)
- `force_destroy` (bool, default `false`)
- `enable_versioning` (bool, default `true`) – Strongly recommended.
- `uniform_bucket_level_access` (bool, default `true`)
- `kms_key` (string, optional) – CMEK key resource ID.
- `labels` (map(string), optional)
- `artifacts` (map) – Map of object name → `{ local_path, content_type?, cache_control? }`
- `service_account_readers` (list(string)) – SA emails to grant bucket read.

## Outputs
- `bucket_name`
- `object_urls` (map `name -> gs://...`)
- `object_generations` (map `name -> generation (number)`)
- `object_md5` (map)

## Example: Upload Falcon and grant node SA access
```hcl
module "agents_artifacts" {
  source = "./modules/agents_artifacts"

  project_id   = "artifacts-project"
  bucket_name  = "security-agents-prod"
  create_bucket = true
  bucket_location = "us-central1"

  artifacts = {
    "crowdstrike/falcon-sensor_7.XX.YY_amd64.deb" = {
      local_path   = "./dist/falcon-sensor_7.XX.YY_amd64.deb"
      content_type = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }
  }

  # Cross-project node SAs (from your compute project)
  service_account_readers = [
    "nodes-osconfig@compute-project.iam.gserviceaccount.com"
  ]
}

# Wire into your OS Policy module (pin exact generation)
module "falcon_policy" {
  source             = "./modules/os_policy_falcon"
  project_id         = "compute-project"
  location           = "us-central1-b"
  assignment_name    = "falcon-ubuntu"
  bucket             = module.agents_artifacts.bucket_name
  object             = "crowdstrike/falcon-sensor_7.XX.YY_amd64.deb"
  object_generation  = module.agents_artifacts.object_generations["crowdstrike/falcon-sensor_7.XX.YY_amd64.deb"]
  falcon_cid         = var.falcon_cid

  # target VMs by **GCE instance label** (ensure Gardener places this label on the VM)
  label_key   = "node_kubernetes_io_role"
  label_value = "node"

  rollout_percent = 10
}
