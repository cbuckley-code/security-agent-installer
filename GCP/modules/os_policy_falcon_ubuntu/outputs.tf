output "assignment_name" {
  value       = google_os_config_os_policy_assignment.this.name
  description = "OS Policy Assignment name."
}

output "location" {
  value       = google_os_config_os_policy_assignment.this.location
  description = "Zone of the OS Policy Assignment."
}
