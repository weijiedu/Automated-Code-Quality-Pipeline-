output "cluster_name" {
  description = "The name of the provisioned GKE cluster."
  value       = google_container_cluster.ci_cluster.name
}

output "cluster_region" {
  description = "The region of the provisioned GKE cluster."
  value       = google_container_cluster.ci_cluster.location
}

output "cluster_location" {
  description = "The location used to access the provisioned GKE cluster."
  value       = google_container_cluster.ci_cluster.location
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster."
  value       = google_container_cluster.ci_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster."
  value       = google_container_cluster.ci_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}
