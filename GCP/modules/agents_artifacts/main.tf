provider "google" {
  project = var.project_id
}

# Create or reference the bucket
resource "google_storage_bucket" "this" {
  count                       = var.create_bucket ? 1 : 0
  name                        = var.bucket_name
  location                    = var.bucket_location
  storage_class               = var.storage_class
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = var.uniform_bucket_level_access

  dynamic "versioning" {
    for_each = var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "encryption" {
    for_each = var.kms_key == null ? [] : [1]
    content {
      default_kms_key_name = var.kms_key
    }
  }

  labels = var.labels
}

data "google_storage_bucket" "existing" {
  count = var.create_bucket ? 0 : 1
  name  = var.bucket_name
}

locals {
  bucket_name = var.create_bucket ? google_storage_bucket.this[0].name : data.google_storage_bucket.existing[0].name
}

# Grant bucket-level read to node SAs (UBLA on = bucket-level is preferred)
resource "google_storage_bucket_iam_member" "readers" {
  for_each = toset(var.service_account_readers)
  bucket   = local.bucket_name
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${each.key}"
}

# Upload artifacts (any files, not only .deb)
resource "google_storage_bucket_object" "artifacts" {
  for_each     = var.artifacts
  name         = each.key
  bucket       = local.bucket_name
  source       = each.value.local_path
  content_type = lookup(each.value, "content_type", null)
  cache_control = lookup(each.value, "cache_control", null)

  # Helpful: prevent accidental re-uploads if file is unchanged
  # (terraform already uses hashes but you can pin md5 if desired via source_hash)
}
