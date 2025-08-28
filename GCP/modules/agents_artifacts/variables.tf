variable "project_id" {
  type        = string
  description = "Project that owns the bucket and objects."
}

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket to create or reuse."
}

variable "create_bucket" {
  type        = bool
  default     = true
  description = "If true, create the bucket. If false, reuse an existing bucket_name."
}

variable "bucket_location" {
  type        = string
  default     = "US"
  description = "GCS bucket location (region or multi-region), e.g., US, us-central1."
}

variable "storage_class" {
  type        = string
  default     = "STANDARD"
  description = "GCS storage class."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow terraform to delete non-empty bucket on destroy."
}

variable "enable_versioning" {
  type        = bool
  default     = true
  description = "Enable object versioning so we can pin exact generations."
}

variable "uniform_bucket_level_access" {
  type        = bool
  default     = true
  description = "Enforce UBLA (recommended)."
}

variable "kms_key" {
  type        = string
  default     = null
  description = "Optional CMEK resource ID for default encryption (projects/.../locations/.../keyRings/.../cryptoKeys/...)."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels to set on the bucket."
}

# Map of objects to upload: key = object name in bucket; value = settings for upload.
variable "artifacts" {
  description = <<EOT
Map of artifacts to upload. Keys are object names in the bucket (e.g., "crowdstrike/falcon_7.xx.yy_amd64.deb").
Each value is an object:
{
  local_path   = "/absolute/or/relative/path/to/file.deb"
  content_type = optional("application/vnd.debian.binary-package")
  cache_control = optional("no-store")
}
EOT
  type = map(object({
    local_path    = string
    content_type  = optional(string)
    cache_control = optional(string)
  }))
  default = {}
}

# Service accounts granted read access (cross-project fine).
variable "service_account_readers" {
  type        = list(string)
  default     = []
  description = "List of service account emails to grant roles/storage.objectViewer on the bucket."
}
