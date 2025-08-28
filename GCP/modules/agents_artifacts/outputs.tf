output "bucket_name" {
  value       = local.bucket_name
  description = "The bucket name where artifacts are stored."
}

output "object_urls" {
  value       = { for k, v in google_storage_bucket_object.artifacts : k => "gs://${v.bucket}/${v.name}" }
  description = "Map of object names to gs:// URLs."
}

output "object_generations" {
  value       = { for k, v in google_storage_bucket_object.artifacts : k => tonumber(v.generation) }
  description = "Map of object names to their generation numbers (pin these in OS Policies)."
}

output "object_md5" {
  value       = { for k, v in google_storage_bucket_object.artifacts : k => v.md5hash }
  description = "Map of object names to MD5 hashes."
}
