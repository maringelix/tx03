variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_number" {
  description = "GCP Project Number (numeric ID)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "tx03"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "billing_account_name" {
  description = "Display name of the GCP billing account"
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

variable "alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "notification_channels" {
  description = "List of notification channel IDs for budget alerts"
  type        = list(string)
  default     = []
}

variable "disable_default_iam_recipients" {
  description = "Disable sending alerts to default IAM recipients (billing account admins)"
  type        = bool
  default     = false
}

variable "filter_labels" {
  description = "Map of labels to filter budget (e.g., {environment = ['dev']})"
  type        = map(list(string))
  default     = {}
}

variable "filter_services" {
  description = "List of service IDs to filter budget (e.g., ['services/95FF-2EF5-5EA1'] for GKE)"
  type        = list(string)
  default     = []
}

variable "enable_pubsub" {
  description = "Enable Pub/Sub topic for budget alerts (for Cloud Functions integration)"
  type        = bool
  default     = true
}

variable "enable_cost_spike_alerts" {
  description = "Enable alerts for sudden cost spikes"
  type        = bool
  default     = true
}

variable "cost_spike_threshold" {
  description = "Threshold for cost spike alerts (USD per 5min)"
  type        = number
  default     = 10
}
