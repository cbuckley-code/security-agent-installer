terraform {
  backend "gcs" {
    bucket = "tf-state-mtcdo"
    prefix = "agents-artifacts-mgmt/prod"  # state path inside the bucket
  }
}
