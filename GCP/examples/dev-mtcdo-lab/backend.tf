terraform {
  backend "gcs" {
    bucket = "tf-state-mtcdo"
    prefix = "dev-mtcdo-lab/prod"  # state path inside the bucket
  }
}
