resource "aws_s3_bucket" "state_bucket" {
  bucket = "my-unique-devops-project-state-storage"
  
  # This ensures we don't accidentally delete our 'memory' bucket
  lifecycle {
    prevent_destroy = true
  }
}