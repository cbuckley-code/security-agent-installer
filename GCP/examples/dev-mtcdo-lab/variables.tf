variable "project_id" {
  type        = string
  description = "GCP project that runs the OS policies on the worker VMs."
}

variable "location" {
  type        = string
  default     = "us-central1-b"
  description = "Zone (OS Policy Assignments are zonal)."
}

# ---- Remote state from the artifacts workspace (GCS backend) ----
variable "artifacts_state_bucket" {
  type        = string
  description = "GCS bucket where the artifacts workspace stores Terraform state."
}

variable "artifacts_state_prefix" {
  type        = string
  description = "State prefix/path for the artifacts workspace."
}

# ================
# Falcon (CrowdStrike) Config
# ================
variable "falcon_object_name" {
  type        = string
  default     = "crowdstrike/falcon-sensor_7.25.0-17804_amd64.deb"
  description = "Object name for the Falcon .deb in the artifacts bucket."
}

variable "falcon_cid" {
  type        = string
  sensitive   = true
  description = "CrowdStrike CID (include checksum suffix if applicable)."
}

# ================
# Trend Config
# ================
# Trend (Ubuntu 20/22)
variable "trend_ubuntu20_object_name" {
  type        = string
  default     = "trend/Agent-Core-Ubuntu_20.04-20.0.2-17500.x86_64.deb"
  description = "Object name for the Trend .deb (Ubuntu 20.04) in the artifacts bucket."
}

variable "trend_ubuntu22_object_name" {
  type        = string
  default     = "trend/Agent-Core-Ubuntu_22.04-20.0.2-17500.x86_64.deb"
  description = "Object name for the Trend .deb (Ubuntu 22.04) in the artifacts bucket."
}

variable "dsm_url" {
  type        = string
  default     = ""
  description = "Activation URL (e.g., dsm://agents.workload.us-1.cloudone.trendmicro.com:443/)."
}

variable "tenant_id" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Trend tenant ID for activation."
}

variable "token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Trend activation token."
}

variable "group" {
  type        = string
  default     = "NS2_CHANGE_ME"
  description = "Optional Trend group name (group:<name>) at activation."
}

variable "policy_id" {
  type        = string
  default     = ""
  description = "Optional Trend policy ID (policyid:<id>) at activation."
}

# ================
# Nessus Config
# ================
variable "nessus_object_name" {
  description = "GCS object path for the Nessus Agent .deb"
  default     = "tenable/NessusAgent-10.9.0-ubuntu1604_amd64.deb"
  type        = string
}

variable "tenable_linking_key" {
  description = "Tenable agent linking key."
  type        = string
  sensitive   = true
}

variable "tenable_host" {
  description = "Tenable manager host (Tenable.io default)."
  type        = string
  default     = "cloud.tenable.com"
}

variable "tenable_port" {
  description = "Tenable manager port."
  type        = number
  default     = 443
}

variable "tenable_groups" {
  description = "Optional list of agent groups."
  type        = list(string)
  default     = []
}

variable "agent_name" {
  description = "Optional explicit agent name. If empty, the module will default to gcp-<hostname>."
  type        = string
  default     = ""
}

# ---- Targeting & rollout ----
variable "label_key" {
  type        = string
  default     = "node_os"
  description = "Compute Engine instance label key used for targeting."
}

variable "label_value" {
  type        = string
  default     = "linux"
  description = "Compute Engine instance label value used for targeting."
}

variable "rollout_percent" {
  type        = number
  default     = 10
  description = "Max percent of instances disrupted during rollout."
}
