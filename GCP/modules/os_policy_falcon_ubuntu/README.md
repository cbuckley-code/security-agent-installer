# OS Policy Assignment: CrowdStrike Falcon (Ubuntu)

This module creates a **VM Manager OS Policy Assignment** that:
- Installs the Falcon sensor `.deb` from **GCS** (pinned by `object_generation`)
- Sets your **CID** and keeps `falcon-sensor` enabled & running
- Targets **Ubuntu** VMs carrying a **Compute Engine label** (default gardener nodes `node_kubernetes_io_role=node`)

## Usage
### Baseline
```hcl
module "falcon-ubuntu" {
  source = "./modules/os_policy_falcon_ubuntu"

  project_id        = "my-project"
  location          = "us-central1-b"               # one assignment per zone
  assignment_name   = "falcon-ubuntu"               # unique within zone
  bucket            = "agents-artifacts-bucket"     # in another project is fine
  object            = "crowdstrike/falcon_7.xx.yy_amd64.deb"
  object_generation = 1712345678901234              # pin exact object version
  falcon_cid        = var.falcon_cid                # sensitive

  # Targeting (must be a **GCE instance label**):
  label_key   = "node_os"
  label_value = "linux"

  rollout_percent = 10
}```

### Multi Zonal

---

### Example: call the module for multiple zones
```hcl
locals {
  zones = ["us-central1-b", "us-central1-c"]
}

module "falcon_multi" {
  for_each = toset(local.zones)
  source   = "./modules/os_policy_falcon"

  project_id        = "dev-mtcdo-lab"
  location          = each.key
  assignment_name   = "falcon-ubuntu-${each.key}"
  bucket            = "security-agents-bucket"
  object            = "crowdstrike/falcon-sensor_7.XX.YY_amd64.deb"
  object_generation = 1712345678901234
  falcon_cid        = var.falcon_cid

  label_key   = "node_os"
  label_value = "linux"

  rollout_percent = 10
}```


Then:
terraform init
terraform apply -var="falcon_cid=YOURCID-XXXXXXXXXXXX-XX"

