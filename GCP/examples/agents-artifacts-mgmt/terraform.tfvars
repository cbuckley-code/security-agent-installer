# Project that OWNS the artifacts bucket & objects
project_id  = "dev-mtcdo-lab"

# Bucket to create (or reuse if create_bucket=false in the module)
bucket_name   = "security-agents-prod"
bucket_region = "us-central1"

# Node instance SAs (can be cross-project) that need read access to the bucket
node_service_account_readers = [
  "nodes-osconfig@dev-mtcdo-lab.iam.gserviceaccount.com"
]

