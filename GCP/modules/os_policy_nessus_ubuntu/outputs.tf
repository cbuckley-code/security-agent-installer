output "assignment_id" {
  description = "Provider-assigned ID."
  value       = google_os_config_os_policy_assignment.nessus.id
}

output "assignment_name" {
  description = "OS Policy Assignment name."
  value       = google_os_config_os_policy_assignment.nessus.name
}

output "revision_id" {
  description = "Current assignment revision ID."
  value       = google_os_config_os_policy_assignment.nessus.revision_id
}

output "rollout_state" {
  description = "Rollout state for the current revision."
  value       = google_os_config_os_policy_assignment.nessus.rollout_state
}

output "uid" {
  description = "Server-generated unique ID for this assignment."
  value       = google_os_config_os_policy_assignment.nessus.uid
}

