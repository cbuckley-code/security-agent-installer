provider "google" { project = var.project_id }

resource "google_os_config_os_policy_assignment" "this" {
  name     = var.assignment_name
  location = var.location
  project  = var.project_id

  os_policies {
    id   = "install-configure-trend-ubuntu"
    mode = "ENFORCEMENT"

    # -------- Ubuntu 22.04 --------
    resource_groups {
      inventory_filters {
        os_short_name = "ubuntu"
        os_version    = "22.04"
      }

      # Install .deb for 22.04
      resources {
        id = "install-trend-deb-22"
        pkg {
          desired_state = "INSTALLED"
          deb {
            pull_deps = true
            source {
              gcs {
                bucket     = var.bucket
                object     = var.ubuntu22_object
                generation = var.ubuntu22_object_generation
              }
            }
          }
        }
      }

      # Configure + start service
      resources {
        id = "configure-trend-service-22"
        exec {
          validate {
            interpreter = "SHELL"
            script = <<-EOT
              #!/bin/sh
              set -eu
              if dpkg -s ds-agent >/dev/null 2>&1; then
                systemctl is-active --quiet ds_agent && exit 100
              fi
              exit 101
            EOT
          }
          enforce {
            interpreter = "SHELL"
            script = <<-EOT
              #!/bin/sh
              set -eu
              OPTS=""
              [ -n "${var.group}" ] && OPTS="$OPTS \"group:${var.group}\""
              [ -n "${var.policy_id}" ] && OPTS="$OPTS \"policyid:${var.policy_id}\""
              # shellcheck disable=SC2086
              /opt/ds_agent/dsa_control -a ${var.dsm_url} \
                "tenantID:${var.tenant_id}" "token:${var.token}" $OPTS
              systemctl enable --now ds_agent || true
              /opt/ds_agent/dsa_control -m || true
              exit 100
            EOT
          }
        }
      }
    }

    # -------- Ubuntu 20.04 --------
    resource_groups {
      inventory_filters {
        os_short_name = "ubuntu"
        os_version    = "20.04"
      }

      resources {
        id = "install-trend-deb-20"
        pkg {
          desired_state = "INSTALLED"
          deb {
            pull_deps = true
            source {
              gcs {
                bucket     = var.bucket
                object     = var.ubuntu20_object
                generation = var.ubuntu20_object_generation
              }
            }
          }
        }
      }

      resources {
        id = "configure-trend-service-20"
        exec {
          validate {
            interpreter = "SHELL"
            script = <<-EOT
              #!/bin/sh
              set -eu
              if dpkg -s ds-agent >/dev/null 2>&1; then
                systemctl is-active --quiet ds_agent && exit 100
              fi
              exit 101
            EOT
          }
          enforce {
            interpreter = "SHELL"
            script = <<-EOT
              #!/bin/sh
              set -eu
              OPTS=""
              [ -n "${var.group}" ] && OPTS="$OPTS \"group:${var.group}\""
              [ -n "${var.policy_id}" ] && OPTS="$OPTS \"policyid:${var.policy_id}\""
              # shellcheck disable=SC2086
              /opt/ds_agent/dsa_control -a ${var.dsm_url} \
                "tenantID:${var.tenant_id}" "token:${var.token}" $OPTS
              systemctl enable --now ds_agent || true
              /opt/ds_agent/dsa_control -m || true
              exit 100
            EOT
          }
        }
      }
    }
  }

  # Same instance filter you already use
  instance_filter {
    inventories { os_short_name = "ubuntu" }
    inclusion_labels { labels = { (var.label_key) = var.label_value } }
  }

  rollout {
    disruption_budget { percent = var.rollout_percent }
    min_wait_duration = "600s"
  }
}
