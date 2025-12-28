variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_14"
}

variable "tier" {
  description = "Machine tier for Cloud SQL"
  type        = string
  default     = "db-g1-small"  # 1 vCPU shared, 1.7GB RAM - affordable tier for PostgreSQL 14
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "dx03"
}

variable "database_user" {
  description = "Database user name"
  type        = string
  default     = "dx03"
}

variable "network_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "private_vpc_connection_id" {
  description = "ID of the private VPC connection"
  type        = string
}
