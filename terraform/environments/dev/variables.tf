variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "tx03-network"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "tx03-gke-cluster"
}

variable "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "tx03-postgres"
}

variable "service_account_email" {
  description = "Service account email for GitHub Actions"
  type        = string
}
