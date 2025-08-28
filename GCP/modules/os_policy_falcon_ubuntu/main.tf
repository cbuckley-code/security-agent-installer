provider "google" {
  project = var.project_id
}

resource "google_os_config_os_policy_assignment" "this" {
  name     = var.assignment_name
  location = var.location
  project  = var.project_id

  os_policies {
    id   = "install-configure-crowdstrike-ubuntu"
    mode = "ENFORCEMENT"

    resource_groups {
      # 1) Install Falcon .deb from GCS (pin by generation; pull dependencies via apt)
      resources {
        id = "install-falcon-deb"
        pkg {
          desired_state = "INSTALLED"
          deb {
            pull_deps = true
            source {
              gcs {
                bucket     = var.bucket
                object     = var.object
                generation = var.object_generation
              }
            }
          }
        }
      }

      # 2) Ensure CID is set and service is enabled/running
      resources {
        id = "configure-falcon-service"
        exec {
          validate {
            interpreter = "SHELL"
            script = <<-EOT
              #!/bin/sh
              set -eu
              if dpkg -s falcon-sensor >/dev/null 2>&1; then
                CID="$(/opt/CrowdStrike/falconctl -g --cid 2>/dev/null || true)"
                if [ -n "$CID" ] && systemctl is-active --quiet falcon-sensor; then
                  exit 100
                fi
              fi
              exit 101
            EOT
          }
          enforce {
            interpreter = "SHELL"
            script = <<-EOT
              #!/bin/sh
              set -eu
              /opt/CrowdStrike/falconctl -s --cid=${var.falcon_cid}
              systemctl enable --now falcon-sensor
              exit 100
            EOT
          }
        }
      }
    }
  }

  # Target Ubuntu instances that carry the specified Compute Engine label.
  instance_filter {
    inventories {
      os_short_name = "ubuntu"
    }
    inclusion_labels {
      labels = {
        (var.label_key) = var.label_value
      }
    }
  }

  rollout {
    disruption_budget {
      percent = var.rollout_percent
    }
    min_wait_duration = "600s"
  }

  timeouts {
    create = "2h"
    update = "2h"
    delete = "2h"
  }
}
