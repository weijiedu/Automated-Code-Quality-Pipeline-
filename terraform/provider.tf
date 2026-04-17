provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "github" {
  token = var.github_token
  owner = var.github_repo_owner
}

provider "kubernetes" {
  host                   = "https://${module.ci.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.ci.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

data "google_client_config" "default" {}
