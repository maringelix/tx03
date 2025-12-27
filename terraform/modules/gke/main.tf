# GKE Cluster (Autopilot mode for free tier)
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Enable Autopilot mode (fully managed)
  enable_autopilot = true

  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Release channel
  release_channel {
    channel = "REGULAR"
  }

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "tx03"
  }

  # Deletion protection
  deletion_protection = false
}
