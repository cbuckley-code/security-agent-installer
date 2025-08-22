variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "schedule" {
  description = "Cron schedule for running the script (e.g., '0 2 * * *' for daily at 2 AM, '0 */4 * * *' for every 4 hours)"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

variable "script_args" {
  description = "Arguments to pass to the CrowdStrike script"
  type        = string
  default     = ""
}

variable "gcs_installer_path_linux" {
  description = "GCS path to the CrowdStrike installer for Linux (e.g., 'gs://my-bucket/crowdstrike/' - the script will auto-select the appropriate package)"
  type        = string
}

variable "gcs_installer_path_windows" {
  description = "GCS path to the CrowdStrike installer for Windows (e.g., 'gs://my-bucket/crowdstrike/WindowsSensor.exe')"
  type        = string
}

variable "crowdstrike_cid" {
  description = "CrowdStrike Customer ID (CID) for agent registration"
  type        = string
}

variable "target_instances" {
  description = "Instance targeting configuration"
  type = object({
    all = optional(bool, false)
    include_labels = optional(map(string), {})
    exclude_labels = optional(map(string), {})
    zones = optional(list(string), [])
    instance_names = optional(list(string), [])
  })
  default = {
    all = false
    include_labels = {
      security-agent = "crowdstrike"
    }
  }
}
