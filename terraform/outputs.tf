output "ci_cluster_name" {
  description = "The name of the provisioned GKE cluster for Jenkins and SonarQube."
  value       = module.ci.cluster_name
}

output "ci_cluster_region" {
  description = "The region of the provisioned GKE cluster."
  value       = module.ci.cluster_region
}

output "ci_cluster_location" {
  description = "The location used to access the provisioned GKE cluster."
  value       = module.ci.cluster_location
}

output "hadoop_cluster_name" {
  description = "The name of the provisioned Dataproc cluster."
  value       = module.hadoop.cluster_name
}

output "hadoop_cluster_region" {
  description = "The region of the provisioned Dataproc cluster."
  value       = module.hadoop.cluster_region
}

output "hadoop_staging_bucket" {
  description = "The GCS bucket used for Hadoop job staging and results."
  value       = google_storage_bucket.hadoop_staging.name
}

output "jenkins_url" {
  description = "Jenkins URL - Access Jenkins at this address"
  value       = "http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip}"
}

output "jenkins_credentials" {
  description = "Jenkins login credentials"
  value       = "Username: admin | Password: ${var.jenkins_admin_password}"
  sensitive   = true
}

output "sonarqube_url" {
  description = "SonarQube URL - Access SonarQube at this address"
  value       = "To get SonarQube URL, run: kubectl get service sonarqube-service -n default"
}

output "github_webhook_url" {
  description = "GitHub Webhook URL configured for mayavi repository"
  value       = github_repository_webhook.mayavi_jenkins.url
}

output "next_steps" {
  description = "Next steps to complete the setup"
  sensitive   = true
  value       = <<-EOT

    ========================================
    AUTOMATED SETUP COMPLETE
    ========================================

    Jenkins URL: http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip}
    Username: admin
    Password: ${var.jenkins_admin_password}

    GitHub Webhook: AUTOMATICALLY CONFIGURED ✅

    MANUAL STEPS (First Time Only):
    --------------------------------
    1. Access SonarQube:
       kubectl get service sonarqube-service -n default

    2. Login to SonarQube (admin/admin) and change password

    3. Create SonarQube token:
       User > My Account > Security > Generate Token

    4. If not already done, add the SonarQube token to terraform.tfvars:
       sonar_token = "sqa_yourTokenHere"

    5. Run terraform apply again to update Jenkins with SonarQube token

    VERIFICATION:
    -------------
    - Jenkins pipeline 'mayavi-pipeline' should be created automatically
    - GitHub webhook is configured to trigger on push/PR
    - Push to mayavi repo to test the complete workflow

    ========================================
  EOT
}
