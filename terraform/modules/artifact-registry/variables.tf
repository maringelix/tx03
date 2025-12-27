variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "repository_id" {
  description = "ID of the Artifact Registry repository"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "tx03"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for GitHub Actions"
  type        = string
}
