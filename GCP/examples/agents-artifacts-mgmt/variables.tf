variable "project_id"  { type = string }
variable "bucket_name" { type = string }

variable "bucket_region" {
  type    = string
  default = "us-central1"
}

variable "node_service_account_readers" {
  type        = list(string)
  default     = []
  description = "Service account emails granted Storage Object Viewer on the bucket."
}
