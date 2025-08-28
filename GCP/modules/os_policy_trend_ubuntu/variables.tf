variable "project_id" {
  type        = string
  description = "GCP project ID hosting the VMs."
}

variable "location" {
  type        = string
  description = "Zone for the OS Policy Assignment (e.g., us-central1-b)."
}

variable "assignment_name" {
  type        = string
  default     = "install-configure-trend-ubuntu"
  description = "OS Policy Assignment name (unique per project/zone)."
}

# --- GCS artifacts (pin by generation) ---
variable "bucket" {
  type        = string
  description = "GCS bucket containing the Trend agent packages."
}

variable "ubuntu20_object" {
  type        = string
  description = "Object path to the Ubuntu 20.04 .deb in the bucket."
}

variable "ubuntu20_object_generation" {
  type        = number
  description = "Generation number for the Ubuntu 20.04 .deb (pin exact artifact)."
}

variable "ubuntu22_object" {
  type        = string
  description = "Object path to the Ubuntu 22.04 .deb in the bucket."
}

variable "ubuntu22_object_generation" {
  type        = number
  description = "Generation number for the Ubuntu 22.04 .deb (pin exact artifact)."
}

# --- Trend activation (Cloud One / Deep Security) ---
variable "dsm_url" {
  type        = string
  description = "Activation URL (e.g., dsm://agents.workload.us-1.cloudone.trendmicro.com:443/)."
}

variable "tenant_id" {
  type        = string
  sensitive   = true
  description = "Trend tenant ID used for agent activation."
}

variable "token" {
  type        = string
  sensitive   = true
  description = "Trend activation token."
}

variable "group" {
  type        = string
  default     = ""
  description = "Optional group name to assign at activation (group:<name>)."
}

variable "policy_id" {
  type        = string
  default     = ""
  description = "Optional policy ID to assign at activation (policyid:<id>)."
}

# --- Targeting & rollout ---
variable "label_key" {
  type        = string
  default     = "node_kubernetes_io_role"
  description = "Compute Engine instance label key used for targeting."
}

variable "label_value" {
  type        = string
  default     = "node"
  description = "Compute Engine instance label value used for targeting."
}

variable "rollout_percent" {
  type        = number
  default     = 10
  description = "Max percent of instances disrupted during rollout."
}
