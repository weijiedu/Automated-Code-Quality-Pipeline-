# variables.tf

variable "project_id" {
  description = "cmu-14848-486002"
  type        = string
}

variable "region" {
  description = "The region to deploy resources in"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "The zone to deploy the CI cluster in"
  type        = string
  default     = "us-west1-a"
}
