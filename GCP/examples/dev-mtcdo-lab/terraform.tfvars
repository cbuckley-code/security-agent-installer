# Project that RUNS the OS Policy on the worker VMs
project_id = "dev-mtcdo-lab"
location   = "us-central1-b"  # zone; one assignment per zone

# Point to the artifacts example’s Terraform state (GCS backend)
artifacts_state_bucket = "tf-state-mtcdo"
artifacts_state_prefix = "agents-artifacts-mgmt/prod"  # folder/key prefix used by that workspace

# CrowdStrike CID (treat as sensitive)
falcon_cid = "897ADC62594B49CABBA935A0DC80774B-B1"

# Trend 
dsm_url = "dsm://agents.workload.us-1.cloudone.trendmicro.com:443/"
group = "DEV_MTCDO_LAB"

# Nessus
tenable_linking_key = "REDACTED-LINKING-KEY"
# Optional overrides:
# tenable_host      = "cloud.tenable.com"
# tenable_port      = 443
# tenable_groups    = ["gcp", "prod"]
# agent_name        = "gcp-my-hostname"

# Targeting (Compute Engine instance label; NOT a Kubernetes label)
label_key   = "node_kubernetes_io_role"
label_value = "node"

# Rollout pacing
rollout_percent = 10
