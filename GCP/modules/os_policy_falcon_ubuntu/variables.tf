variable "project_id" {
  type        = string
  description = "GCP project ID hosting the VMs."
}

variable "location" {
  type        = string
  description = "Zone for the OS Policy Assignment (zonal resource, e.g., us-central1-b)."
}

variable "assignment_name" {
  type        = string
  default     = "falcon-ubuntu"
  description = "OS Policy Assignment name (unique per project/zone)."
}

variable "bucket" {
  type        = string
  description = "GCS bucket containing the Falcon sensor .deb."
}

variable "object" {
  type        = string
  description = "Object path to the Falcon .deb (e.g., sensors/falcon-sensor_7.xx.yy_amd64.deb)."
}

variable "object_generation" {
  type        = number
  description = "GCS object generation to pin the exact artifact (strongly recommended)."
}

variable "falcon_cid" {
  type        = string
  sensitive   = true
  description = "CrowdStrike CID (include checksum suffix if your org uses one)."
}

variable "label_key" {
  type        = string
  default     = "node_kubernetes_io_role"
  description = "Compute Engine instance label key to target (must be a valid GCE label key).  This is taretting Gardener nodes by default."
}

variable "label_value" {
  type        = string
  default     = "node"
  description = "Compute Engine instance label value to target."
}

variable "rollout_percent" {
  type        = number
  default     = 10
  description = "Max % of instances disrupted during rollout."
}
