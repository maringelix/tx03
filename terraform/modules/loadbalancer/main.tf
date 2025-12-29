# ============================================================================
# Load Balancer Module - Static IP and SSL Certificate
# ============================================================================
# This module creates a static global IP address and managed SSL certificate
# for the GKE Ingress Load Balancer

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# ============================================================================
# Global Static IP Address
# ============================================================================
resource "google_compute_global_address" "ingress_ip" {
  project      = var.project_id
  name         = "${var.name_prefix}-ingress-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  description  = "Static IP for ${var.name_prefix} Load Balancer"

  labels = merge(var.labels, {
    component = "loadbalancer"
    managed   = "terraform"
  })
}

# ============================================================================
# Managed SSL Certificate (Google-managed, automatic renewal)
# ============================================================================
resource "google_compute_managed_ssl_certificate" "ingress_cert" {
  count   = var.enable_ssl ? 1 : 0
  project = var.project_id
  name    = "${var.name_prefix}-ingress-cert"

  managed {
    domains = var.domains
  }

  description = "Managed SSL certificate for ${var.name_prefix}"

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# DNS A Record (optional, if Cloud DNS zone is provided)
# ============================================================================
resource "google_dns_record_set" "ingress_a_record" {
  count        = var.dns_zone_name != null && length(var.domains) > 0 ? length(var.domains) : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.domains[count.index]}."
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.ingress_ip.address]
}
