output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "gke_subnet_id" {
  description = "The ID of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.id
}

output "gke_subnet_name" {
  description = "The name of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "gke_subnet_self_link" {
  description = "The self link of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.self_link
}

output "gke_pods_range_name" {
  description = "The name of the secondary range for pods"
  value       = "gke-pods"
}

output "gke_services_range_name" {
  description = "The name of the secondary range for services"
  value       = "gke-services"
}

output "private_vpc_connection_id" {
  description = "The ID of the private VPC connection"
  value       = google_service_networking_connection.private_vpc_connection.id
}
