terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "gcs" {
    bucket = "tfstate-tx03-f9d2e263"
    prefix = "terraform/state/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_id        = var.project_id
  region            = var.region
  network_name      = var.network_name
  gke_subnet_cidr   = "10.0.0.0/24"
  gke_pods_cidr     = "10.1.0.0/16"
  gke_services_cidr = "10.2.0.0/16"
}

# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  cluster_name        = var.cluster_name
  environment         = var.environment
  network_self_link   = module.networking.network_self_link
  subnet_self_link    = module.networking.gke_subnet_self_link
  pods_range_name     = module.networking.gke_pods_range_name
  services_range_name = module.networking.gke_services_range_name

  depends_on = [module.networking]
}

# Cloud SQL Module
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id                = var.project_id
  region                    = var.region
  instance_name             = var.database_instance_name
  database_version          = "POSTGRES_14"
  tier                      = var.database_tier
  disk_size                 = 10
  database_name             = "dx03"
  database_user             = "dx03"
  network_self_link         = module.networking.network_self_link
  private_vpc_connection_id = module.networking.private_vpc_connection_id

  depends_on = [module.networking]
}

# Artifact Registry Module
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id            = var.project_id
  region                = var.region
  repository_id         = "dx03"
  project_name          = "tx03"
  environment           = var.environment
  service_account_email = var.service_account_email
}

# Cloud Armor Module
module "cloud_armor" {
  source = "../../modules/cloud-armor"

  project_id                 = var.project_id
  policy_name                = "tx03-waf-policy"
  project_name               = "tx03"
  enable_rate_limiting       = true
  rate_limit_threshold       = 100
  ban_duration_sec           = 600
  enable_adaptive_protection = true
}

# Load Balancer Module (Static IP + SSL Certificate)
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_id  = var.project_id
  name_prefix = "tx03-${var.environment}"
  environment = var.environment

  # SSL enabled with dx03.ddns.net domain
  enable_ssl = true
  domains    = ["dx03.ddns.net"]

  labels = {
    environment = var.environment
    project     = "tx03"
    managed-by  = "terraform"
  }
}
