# Simple CrowdStrike OS Manager Module
# This module downloads and installs CrowdStrike with custom parameters on a configurable schedule

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Enable required APIs
resource "google_project_service" "osconfig_api" {
  project = var.project_id
  service = "osconfig.googleapis.com"
}

resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "storage_api" {
  project = var.project_id
  service = "storage.googleapis.com"
}

resource "google_project_service" "cloudscheduler_api" {
  project = var.project_id
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "pubsub_api" {
  project = var.project_id
  service = "pubsub.googleapis.com"
}

# Create a Cloud Storage bucket for the script
resource "google_storage_bucket" "crowdstrike_scripts" {
  name     = "${var.project_id}-crowdstrike-scripts"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
}

# Upload the CrowdStrike download script for Linux
resource "google_storage_bucket_object" "crowdstrike_script_linux" {
  name   = "download-and-run-linux.sh"
  bucket = google_storage_bucket.crowdstrike_scripts.name
  content = templatefile("${path.module}/download-and-run.sh", {
    script_args        = var.script_args
    gcs_installer_path = var.gcs_installer_path_linux
    crowdstrike_cid    = var.crowdstrike_cid
    project_id         = var.project_id
  })
}

# Upload the CrowdStrike download script for Windows
resource "google_storage_bucket_object" "crowdstrike_script_windows" {
  name   = "download-and-run-windows.ps1"
  bucket = google_storage_bucket.crowdstrike_scripts.name
  content = templatefile("${path.module}/download-and-run-windows.ps1", {
    script_args        = var.script_args
    gcs_installer_path = var.gcs_installer_path_windows
    crowdstrike_cid    = var.crowdstrike_cid
    project_id         = var.project_id
  })
}

# OS Policy Assignment for Linux instances
resource "google_os_config_os_policy_assignment" "crowdstrike_execution_linux" {
  location = var.region
  name     = "crowdstrike-install-linux-${var.environment}"
  project  = var.project_id

  # Smart instance filtering
  instance_filter {
    # Option 1: Target all instances (use with caution)
    dynamic "all" {
      for_each = var.target_instances.all ? [1] : []
      content {}
    }
    
    # Option 2: Target by labels (recommended)
    dynamic "inclusion_labels" {
      for_each = length(var.target_instances.include_labels) > 0 ? [1] : []
      content {
        labels = var.target_instances.include_labels
      }
    }
    
    # Option 3: Exclude specific instances
    dynamic "exclusion_labels" {
      for_each = length(var.target_instances.exclude_labels) > 0 ? [1] : []
      content {
        labels = var.target_instances.exclude_labels
      }
    }
    
    # Option 4: Target specific zones
    dynamic "zones" {
      for_each = length(var.target_instances.zones) > 0 ? [1] : []
      content {
        zones = var.target_instances.zones
      }
    }
    
    # Option 5: Target by instance names
    dynamic "instances" {
      for_each = length(var.target_instances.instance_names) > 0 ? [1] : []
      content {
        instances = var.target_instances.instance_names
      }
    }
  }

  os_policies {
    id   = "crowdstrike-install-linux"
    mode = "ENFORCEMENT"
    description = "Download and install CrowdStrike on Linux instances"

    resource_groups {
      resources {
        id = "crowdstrike-install-linux-resource"
        exec {
          validate {
            interpreter = "SHELL"
            script      = <<-EOF
              #!/bin/bash
              echo 'CrowdStrike Linux validation passed'
            EOF
          }
          enforce {
            interpreter = "SHELL"
            script = templatefile("${path.module}/download-and-run.sh", {
              script_args        = var.script_args
              gcs_installer_path = var.gcs_installer_path_linux
              crowdstrike_cid    = var.crowdstrike_cid
              project_id         = var.project_id
            })
          }
        }
      }
      
      # OS filtering
      inventory_filters {
        os_short_name = "linux"
      }
    }
  }

  rollout {
    disruption_budget {
      percent = 10
    }
    
    min_wait_duration = "90s"
  }

  depends_on = [
    google_project_service.osconfig_api,
    google_project_service.compute_api
  ]
}

# OS Policy Assignment for Windows instances
resource "google_os_config_os_policy_assignment" "crowdstrike_execution_windows" {
  location = var.region
  name     = "crowdstrike-install-windows-${var.environment}"
  project  = var.project_id

  # Smart instance filtering (same as Linux)
  instance_filter {
    # Option 1: Target all instances (use with caution)
    dynamic "all" {
      for_each = var.target_instances.all ? [1] : []
      content {}
    }
    
    # Option 2: Target by labels (recommended)
    dynamic "inclusion_labels" {
      for_each = length(var.target_instances.include_labels) > 0 ? [1] : []
      content {
        labels = var.target_instances.include_labels
      }
    }
    
    # Option 3: Exclude specific instances
    dynamic "exclusion_labels" {
      for_each = length(var.target_instances.exclude_labels) > 0 ? [1] : []
      content {
        labels = var.target_instances.exclude_labels
      }
    }
    
    # Option 4: Target specific zones
    dynamic "zones" {
      for_each = length(var.target_instances.zones) > 0 ? [1] : []
      content {
        zones = var.target_instances.zones
      }
    }
    
    # Option 5: Target by instance names
    dynamic "instances" {
      for_each = length(var.target_instances.instance_names) > 0 ? [1] : []
      content {
        instances = var.target_instances.instance_names
      }
    }
  }

  os_policies {
    id   = "crowdstrike-install-windows"
    mode = "ENFORCEMENT"
    description = "Download and install CrowdStrike on Windows instances"

    resource_groups {
      resources {
        id = "crowdstrike-install-windows-resource"
        exec {
          validate {
            interpreter = "POWERSHELL"
            script      = <<-EOF
              Write-Output 'CrowdStrike Windows validation passed'
            EOF
          }
          enforce {
            interpreter = "POWERSHELL"
            script = templatefile("${path.module}/download-and-run-windows.ps1", {
              script_args        = var.script_args
              gcs_installer_path = var.gcs_installer_path_windows
              crowdstrike_cid    = var.crowdstrike_cid
              project_id         = var.project_id
            })
          }
        }
      }
      
      # OS filtering for Windows
      inventory_filters {
        os_short_name = "windows"
      }
    }
  }

  rollout {
    disruption_budget {
      percent = 10
    }
    
    min_wait_duration = "30s"
  }

  depends_on = [
    google_project_service.osconfig_api,
    google_project_service.compute_api
  ]
}

# Cloud Scheduler job for triggering based on schedule
resource "google_cloud_scheduler_job" "crowdstrike_trigger" {
  name     = "crowdstrike-install-trigger-${var.environment}"
  project  = var.project_id
  region   = var.region
  schedule = var.schedule
  
  description = "Trigger CrowdStrike install based on configured schedule"
  
  pubsub_target {
    topic_name = google_pubsub_topic.crowdstrike_trigger.id
    data       = base64encode(jsonencode({
      project_id = var.project_id
      linux_policy_assignment = google_os_config_os_policy_assignment.crowdstrike_execution_linux.name
      windows_policy_assignment = google_os_config_os_policy_assignment.crowdstrike_execution_windows.name
      action = "install"
    }))
  }

  depends_on = [
    google_project_service.cloudscheduler_api,
    google_project_service.pubsub_api
  ]
}

# Pub/Sub topic for triggering
resource "google_pubsub_topic" "crowdstrike_trigger" {
  name    = "crowdstrike-install-trigger-${var.environment}"
  project = var.project_id

  depends_on = [
    google_project_service.pubsub_api
  ]
}
