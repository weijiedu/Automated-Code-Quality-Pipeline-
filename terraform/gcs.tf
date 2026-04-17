resource "google_storage_bucket" "hadoop_staging" {
  name          = "${var.project_id}-hadoop-staging"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}
