variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "policy_name" {
  description = "Name of the Cloud Armor security policy"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "tx03"
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Number of requests per minute before rate limiting kicks in"
  type        = number
  default     = 100
}

variable "ban_duration_sec" {
  description = "Duration in seconds to ban violating IPs"
  type        = number
  default     = 600 # 10 minutes
}

variable "enable_adaptive_protection" {
  description = "Enable adaptive protection against DDoS"
  type        = bool
  default     = true
}
