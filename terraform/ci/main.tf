# GKE Cluster for CI/CD
resource "google_container_cluster" "ci_cluster" {
  name     = "jenkins-sonar-cluster"
  location = var.zone

  # We delete the default node pool to use a custom one[cite: 58].
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
}

# Custom Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "ci-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.ci_cluster.name
  node_count = 1

  node_config {
    # e2-standard-2 provides 8GB RAM, which is sufficient for Jenkins + SonarQube.
    machine_type = "e2-standard-2"
    disk_size_gb = 20
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
