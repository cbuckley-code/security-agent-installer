# Nessus Agent – Ubuntu via OS Config OSPolicy (GCP)

Terraform module that deploys the **Tenable Nessus Agent** to Ubuntu VMs using **OS Config OSPolicy Assignments**. It pulls a single **multi‑Ubuntu** `.deb` from **GCS**, installs it, and **links** the agent to your Tenable manager (Tenable.io or on‑prem) using your **linking key** and optional groups.

> This mirrors the CrowdStrike approach you already use: package from artifact storage + OSPolicy install + post‑install link.

## What it does

- Targets instances by **labels** and **Ubuntu inventory**.
- Installs **Nessus Agent** from a **GCS object** (`deb` supports multiple Ubuntu LTS releases).
- Links to your Tenable manager with `nessuscli agent link` arguments.
- Ensures `nessus-agent` service is **enabled and active**.
- Safe **rollout** (disruption budget + min wait).

## Inputs (high‑value)

- **`nessus_gcs_bucket` / `nessus_gcs_object`**: where your `.deb` lives (artifact project bucket).
- **`tenable_linking_key`**: secure linking key (Sensitive).
- **`tenable_host`/`tenable_port`**: defaults to Tenable.io (`cloud.tenable.com:443`).
- **`tenable_groups`**: optional groups.
- **`instance_label_filter`**: label match for your targets.
- **`zone`**, **`assignment_name`**, **`project_id`**.

## Example

```hcl
module "nessus_policy_usc1a" {
  source          = "./modules/nessus_os_policy"
  project_id      = var.project_id
  zone            = "us-central1-a"
  assignment_name = "nessus-agent-ubuntu"

  instance_label_filter = {
    os  = "ubuntu"
    env = "prod"
  }

  nessus_gcs_bucket   = "artifact-mgt-prod"
  nessus_gcs_object   = "tenable/NessusAgent-10.9.0-ubuntu1604_amd64.deb"
  # nessus_gcs_generation = 173847239548732  # optional pin

  tenable_linking_key = var.tenable_linking_key
  tenable_groups      = ["gcp", "prod"]
  # tenable_host      = "cloud.tenable.com" # default
  # tenable_port      = 443                  # default

  rollout_percent    = 10
  min_wait_duration  = "600s"
}
```

> **Zonal**: OSPolicy Assignments are zonal. Create one module instance per zone you target, or wrap this module in a higher‑level `for_each` over zones.

## Uploading the agent to GCS

Your artifact mgt job should push the `.deb` to a stable GCS location, e.g.:
```
gs://artifact-mgt-prod/tenable/NessusAgent-10.9.0-ubuntu1604_amd64.deb
```
For immutability, **set and use the object generation** (exposed as `nessus_gcs_generation`).

## Verify on a VM

```bash
systemctl status nessus-agent
/opt/nessus_agent/sbin/nessuscli agent status
/opt/nessus_agent/sbin/nessuscli agent info
```

If you see `Not linked`, the validate step will fail and enforce will re‑link on the next run. You can also **force re‑link** by clearing the local link state and re‑applying (or bumping the assignment).

## Common pitfalls

- **409 already exists**: Assignment name must be unique *per zone*. Change `assignment_name` or destroy the old one.
- **Wrong target**: Don’t leave `instance_label_filter` empty unless you mean to hit *every* VM in that zone.
- **No egress to Tenable**: Linking requires outbound 443 to your Tenable host. If you proxy egress, bake it into the VM or use system proxy env vars.
- **Out‑of‑date agent**: Keep the artifact fresh; Tenable regularly releases fixes. Pin by `nessus_gcs_generation` if you need repeatable builds.

## Permissions / APIs

- APIs: `osconfig.googleapis.com`, `compute.googleapis.com`
- Roles for the deployer: `roles/osconfig.admin`, `roles/compute.viewer` (or granular equivalents).

## Uninstall (manual)

```bash
sudo systemctl stop nessus-agent || true
sudo /opt/nessus_agent/sbin/nessuscli agent unlink || true
sudo dpkg -r nessus-agent || sudo apt-get remove -y nessus-agent
sudo rm -rf /opt/nessus_agent
```

---

**Blunt note:** this module won’t manage Tenable policies, scans, or exceptions. It **only** installs & links the agent reliably across Ubuntu LTS via OS Config. Manage the rest in Tenable. 
