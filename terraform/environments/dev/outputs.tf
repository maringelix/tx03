# Networking Outputs
output "network_name" {
  description = "Name of the VPC network"
  value       = module.networking.network_name
}

output "gke_subnet_name" {
  description = "Name of the GKE subnet"
  value       = module.networking.gke_subnet_name
}

# GKE Outputs
output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

# Cloud SQL Outputs
output "cloudsql_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = module.cloudsql.instance_name
}

output "cloudsql_connection_name" {
  description = "Connection name of the Cloud SQL instance"
  value       = module.cloudsql.instance_connection_name
}

output "cloudsql_private_ip" {
  description = "Private IP of the Cloud SQL instance"
  value       = module.cloudsql.instance_private_ip
}

output "database_name" {
  description = "Name of the database"
  value       = module.cloudsql.database_name
}

output "database_user" {
  description = "Database user"
  value       = module.cloudsql.database_user
}

output "database_password" {
  description = "Database password"
  value       = module.cloudsql.database_password
  sensitive   = true
}

# Artifact Registry Outputs
output "artifact_registry_url" {
  description = "URL of the Artifact Registry"
  value       = module.artifact_registry.repository_url
}

output "artifact_registry_id" {
  description = "ID of the Artifact Registry repository"
  value       = module.artifact_registry.repository_id
}

# Cloud Armor Outputs
output "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor WAF policy"
  value       = module.cloud_armor.policy_name
}

output "cloud_armor_policy_id" {
  description = "ID of the Cloud Armor WAF policy"
  value       = module.cloud_armor.policy_id
}
