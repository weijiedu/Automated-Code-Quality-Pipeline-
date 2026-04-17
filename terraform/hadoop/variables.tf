variable "project_id" {
  description = "Your Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "The specific GCP zone to deploy resources in"
  type        = string
  default     = "us-west1-a"
}