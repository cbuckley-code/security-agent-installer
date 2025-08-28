# Variables (CONSISTENT with Falcon/Trend)

variable "project_id" { type = string }
variable "location"   { type = string } # zone like "us-central1-a"
variable "assignment_name" { type = string }

# Label targeting
variable "label_key" {
  type        = string
  default     = "node_kubernetes_io_role"
  description = "GCE label key to target."
}
variable "label_value" {
  type        = string
  default     = "node"
  description = "GCE label value to target."
}

# Artifact inputs
variable "bucket" { type = string }
variable "object" { type = string }
variable "object_generation" {
  type    = number
  default = null
}

# Tenable linking
variable "tenable_linking_key" {
  type      = string
  sensitive = true
}
variable "tenable_host" {
  type    = string
  default = "cloud.tenable.com"
}
variable "tenable_port" {
  type    = number
  default = 443
}
variable "tenable_groups" {
  type    = list(string)
  default = []
}
variable "agent_name" {
  type    = string
  default = ""
}

# Rollout
variable "rollout_percent" {
  type    = number
  default = 10
}
variable "min_wait_duration" {
  type    = string
  default = "600s"
}
