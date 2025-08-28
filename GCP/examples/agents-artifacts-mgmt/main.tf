terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.28.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

module "agents_artifacts" {
  source = "../../modules/agents_artifacts"

  project_id          = var.project_id
  bucket_name         = var.bucket_name
  bucket_location     = var.bucket_region
  create_bucket       = true
  enable_versioning   = true

  # Put the .deb in ./dist/ before apply
  artifacts = {
    "crowdstrike/falcon-sensor_7.25.0-17804_amd64.deb" = {
      local_path    = "${path.root}/dist/falcon-sensor_7.25.0-17804_amd64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }

    "trend/Agent-Core-Ubuntu_20.04-20.0.2-17500.x86_64.deb" = {
      local_path    = "${path.root}/dist/Agent-Core-Ubuntu_20.04-20.0.2-17500.x86_64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }

    "trend/Agent-Core-Ubuntu_22.04-20.0.2-17500.x86_64.deb" = {
      local_path    = "${path.root}/dist/Agent-Core-Ubuntu_22.04-20.0.2-17500.x86_64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }

    "tenable/NessusAgent-10.9.0-ubuntu1604_amd64.deb" = {
      local_path    = "${path.root}/dist/NessusAgent-10.9.0-ubuntu1604_amd64.deb"
      content_type  = "application/vnd.debian.binary-package"
      cache_control = "no-store"
    }
  }

  # Grant read to node service accounts (cross-project is fine)
  service_account_readers = var.node_service_account_readers
}

output "bucket_name"        { value = module.agents_artifacts.bucket_name }
output "object_generations" { value = module.agents_artifacts.object_generations }
