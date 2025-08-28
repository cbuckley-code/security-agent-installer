# ============================================================================
# Nessus Agent for Ubuntu via OS Config OSPolicy Assignment (Google Cloud)
# Consistent interface with Falcon/Trend modules.
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

resource "google_os_config_os_policy_assignment" "nessus" {
  project  = var.project_id
  location = var.location   # ZONAL: pass a zone like "us-central1-a"
  name     = var.assignment_name

  # --- Instance filter (match your Falcon/Trend pattern) ---
  instance_filter {
    inclusion_labels {
      labels = { "${var.label_key}" = var.label_value }
    }
    inventories {
      os_short_name = "ubuntu"
    }
  }

  # --- Rollout controls ---
  rollout {
    disruption_budget { percent = var.rollout_percent }
    min_wait_duration = var.min_wait_duration
  }

  # --- Policies ---
  os_policies {
    id   = "install-nessus-agent-ubuntu"
    mode = "ENFORCEMENT"

    # RG1: install package from GCS (DEB)
    resource_groups {
      resources {
        id = "install-nessus-deb"
        pkg {
          desired_state = "INSTALLED"
          deb {
            source {
              gcs {
                bucket     = var.bucket
                object     = var.object
                generation = var.object_generation
              }
            }
            pull_deps = true
          }
        }
      }
    }

    # RG2: link agent to Tenable and ensure service is running
    resource_groups {
      resources {
        id = "configure-nessus-service"
        exec {
          # Validate: agent linked AND service active
          validate {
            interpreter = "SHELL"
            script = <<-EOT
              set -eu
              [ -x /opt/nessus_agent/sbin/nessuscli ] || exit 1
              systemctl is-active nessus-agent >/dev/null 2>&1 || exit 1
              if /opt/nessus_agent/sbin/nessuscli agent status 2>/dev/null | grep -qi "Linked to:"; then
                exit 0
              else
                exit 1
              fi
EOT
          }

          # Enforce: link the agent and ensure service enabled/started
          enforce {
            interpreter = "SHELL"
            script = <<-EOT
              set -eu
              systemctl enable --now nessus-agent || true

              AGENT_NAME="${var.agent_name}"
              if [ -z "$AGENT_NAME" ]; then
                AGENT_NAME="gcp-$(hostname)"
              fi

              if ! /opt/nessus_agent/sbin/nessuscli agent status 2>/dev/null | grep -qi "Linked to:"; then
                /opt/nessus_agent/sbin/nessuscli agent link \
                  --key="${var.tenable_linking_key}" \
                  --host="${var.tenable_host}" \
                  --port="${var.tenable_port}" \
                  --groups="${join(",", var.tenable_groups)}" \
                  --name="$AGENT_NAME"
              fi

              systemctl restart nessus-agent || true
EOT
          }
        }
      }
    }
  }

  # --- Timeouts (avoid flakiness on large fleets) ---
  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }
}
