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

# Pull outputs from the artifacts workspace (GCS backend example)
data "terraform_remote_state" "artifacts" {
  backend = "gcs"
  config = {
    bucket = var.artifacts_state_bucket
    prefix = var.artifacts_state_prefix
  }
}

locals {
  bucket_name = data.terraform_remote_state.artifacts.outputs.bucket_name
  generations = data.terraform_remote_state.artifacts.outputs.object_generations

  # Falcon generation
  falcon_gen  = tonumber(local.generations[var.falcon_object_name])

  # Trend generations
  trend20_gen = tonumber(local.generations[var.trend_ubuntu20_object_name])
  trend22_gen = tonumber(local.generations[var.trend_ubuntu22_object_name])

  # Nessus generation
  nessus_gen = tonumber(local.generations[var.nessus_object_name])
}

# =========================
# Falcon (DELETE this block if you don't want Falcon)
# =========================
module "falcon_policy" {
  source = "../../modules/os_policy_falcon_ubuntu"

  project_id        = var.project_id
  location          = var.location
  assignment_name   = "install-configure-crowdstrike-ubuntu-${var.location}"

  bucket            = local.bucket_name
  object            = var.falcon_object_name
  object_generation = local.falcon_gen

  falcon_cid        = var.falcon_cid

  label_key         = var.label_key
  label_value       = var.label_value
  rollout_percent   = var.rollout_percent
}

# =========================
# Trend (DELETE this block if you don't want Trend)
# =========================
module "trend_policy" {
  source = "../../modules/os_policy_trend_ubuntu"

  project_id        = var.project_id
  location          = var.location
  assignment_name   = "install-configure-trend-ubuntu-${var.location}"

  bucket                     = local.bucket_name
  ubuntu20_object            = var.trend_ubuntu20_object_name
  ubuntu20_object_generation = local.trend20_gen
  ubuntu22_object            = var.trend_ubuntu22_object_name
  ubuntu22_object_generation = local.trend22_gen

  dsm_url    = var.dsm_url
  tenant_id  = var.tenant_id
  token      = var.token
  group      = var.group
  policy_id  = var.policy_id

  label_key       = var.label_key
  label_value     = var.label_value
  rollout_percent = var.rollout_percent
}

# =========================
# Nessus (DELETE this block if you don't want Nessus (Tenable))
# =========================
module "nessus_policy" {
  source = "../../modules/os_policy_nessus_ubuntu"

  project_id      = var.project_id
  location        = var.location
  assignment_name = "install-configure-nessus-ubuntu-${var.location}"

  # Artifact location
  bucket            = local.bucket_name
  object            = var.nessus_object_name
  object_generation = local.nessus_gen

  # Tenable linking
  tenable_linking_key = var.tenable_linking_key
  tenable_host        = var.tenable_host
  tenable_port        = var.tenable_port
  tenable_groups      = var.tenable_groups
  agent_name          = var.agent_name

  # Targeting & rollout (same interface as Falcon/Trend)
  label_key       = var.label_key
  label_value     = var.label_value
  rollout_percent = var.rollout_percent
}