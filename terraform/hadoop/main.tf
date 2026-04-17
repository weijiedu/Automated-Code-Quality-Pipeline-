resource "google_dataproc_cluster" "hadoop_cluster" {
  name   = "hadoop-course-cluster"
  region = var.region

  cluster_config {
    # Force the cluster to be Zonal to save IP and CPU quota
    gce_cluster_config {
      zone             = var.zone
      internal_ip_only = true
    }

    # Master node configuration (1 required)
    master_config {
      num_instances = 1
      machine_type  = "e2-standard-2"
      disk_config {
        boot_disk_size_gb = 30
      }
    }

    # Worker node configuration (3 required)
    worker_config {
      num_instances = 3
      machine_type  = "e2-standard-2"
      disk_config {
        boot_disk_size_gb = 30
      }
    }
  }
}