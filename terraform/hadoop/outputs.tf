output "cluster_name" {
  description = "The name of the provisioned Dataproc cluster"
  value       = google_dataproc_cluster.hadoop_cluster.name
}

output "cluster_region" {
  description = "The region where the cluster was deployed"
  value       = google_dataproc_cluster.hadoop_cluster.region
}