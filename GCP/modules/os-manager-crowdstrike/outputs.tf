output "bucket_name" {
  description = "Name of the Cloud Storage bucket containing CrowdStrike scripts"
  value       = google_storage_bucket.crowdstrike_scripts.name
}

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.crowdstrike_trigger.name
}

output "linux_os_policy_assignment_name" {
  description = "Name of the Linux OS policy assignment"
  value       = google_os_config_os_policy_assignment.crowdstrike_execution_linux.name
}

output "windows_os_policy_assignment_name" {
  description = "Name of the Windows OS policy assignment"
  value       = google_os_config_os_policy_assignment.crowdstrike_execution_windows.name
}

output "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic for triggering"
  value       = google_pubsub_topic.crowdstrike_trigger.name
}

output "linux_script_gcs_path" {
  description = "GCS path to the Linux installation script"
  value       = "gs://${google_storage_bucket.crowdstrike_scripts.name}/${google_storage_bucket_object.crowdstrike_script_linux.name}"
}

output "windows_script_gcs_path" {
  description = "GCS path to the Windows installation script"
  value       = "gs://${google_storage_bucket.crowdstrike_scripts.name}/${google_storage_bucket_object.crowdstrike_script_windows.name}"
}
