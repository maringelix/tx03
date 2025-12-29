output "static_ip_address" {
  description = "The static IP address for the Load Balancer"
  value       = google_compute_global_address.ingress_ip.address
}

output "static_ip_name" {
  description = "The name of the static IP resource"
  value       = google_compute_global_address.ingress_ip.name
}

output "ssl_certificate_id" {
  description = "The ID of the managed SSL certificate"
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.ingress_cert[0].id : null
}

output "ssl_certificate_name" {
  description = "The name of the managed SSL certificate"
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.ingress_cert[0].name : null
}

output "ssl_certificate_domains" {
  description = "The domains configured in the SSL certificate"
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.ingress_cert[0].managed[0].domains : []
}

output "ssl_certificate_status" {
  description = "The status of the SSL certificate"
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.ingress_cert[0].certificate_id : null
}

output "ingress_annotations" {
  description = "Annotations to add to Kubernetes Ingress"
  value = {
    "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.ingress_ip.name
    "networking.gke.io/managed-certificates"      = var.enable_ssl ? google_compute_managed_ssl_certificate.ingress_cert[0].name : ""
    "kubernetes.io/ingress.allow-http"            = var.enable_ssl ? "false" : "true"
  }
}
