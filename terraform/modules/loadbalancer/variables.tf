variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'tx03-dev')"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_ssl" {
  description = "Enable SSL certificate creation"
  type        = bool
  default     = true
}

variable "domains" {
  description = "List of domains for SSL certificate (e.g., ['example.com', 'www.example.com'])"
  type        = list(string)
  default     = []

  validation {
    condition     = var.enable_ssl == false || length(var.domains) > 0
    error_message = "At least one domain is required when SSL is enabled."
  }
}

variable "dns_zone_name" {
  description = "Cloud DNS zone name for automatic DNS record creation (optional)"
  type        = string
  default     = null
}

variable "labels" {
  description = "Additional labels to apply to resources"
  type        = map(string)
  default     = {}
}
