variable "project_id" {
  description = "The Google Cloud project ID used for all Week 8 resources."
  type        = string
}

variable "region" {
  description = "The GCP region for both the CI cluster and the Dataproc cluster."
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "The GCP zone used by the Dataproc cluster."
  type        = string
  default     = "us-west1-a"
}

variable "github_token" {
  description = "GitHub Personal Access Token for creating webhooks and accessing repositories"
  type        = string
  sensitive   = true
}

variable "github_repo_owner" {
  description = "GitHub repository owner (username or organization)"
  type        = string
}

variable "github_username" {
  description = "GitHub username for Jenkins authentication"
  type        = string
}

variable "jenkins_admin_password" {
  description = "Admin password for Jenkins"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "sonar_token" {
  description = "SonarQube authentication token (to be manually created and provided)"
  type        = string
  sensitive   = true
}
