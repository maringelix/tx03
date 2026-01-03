# Billing Budget with Alerting
# Alerts when spending reaches thresholds

data "google_billing_account" "account" {
  display_name = var.billing_account_name
  open         = true
}

resource "google_billing_budget" "project_budget" {
  billing_account = data.google_billing_account.account.id
  display_name    = "${var.project_name}-${var.environment}-budget"

  budget_filter {
    projects = ["projects/${var.project_number}"]
    
    # Filter by labels (optional)
    dynamic "labels" {
      for_each = var.filter_labels
      content {
        key   = labels.key
        values = labels.value
      }
    }
    
    # Filter by services (optional)
    services = var.filter_services
  }

  # Budget amount
  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount)
    }
  }

  # Alert thresholds (50%, 75%, 90%, 100%)
  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.75
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  # Forecasted spend alert (110%)
  threshold_rules {
    threshold_percent = 1.1
    spend_basis       = "FORECASTED_SPEND"
  }

  # Email notifications
  all_updates_rule {
    pubsub_topic = var.enable_pubsub ? google_pubsub_topic.budget_alerts[0].id : null
    
    monitoring_notification_channels = var.notification_channels
    
    disable_default_iam_recipients = var.disable_default_iam_recipients
  }
}

# Pub/Sub topic for budget alerts (optional)
resource "google_pubsub_topic" "budget_alerts" {
  count = var.enable_pubsub ? 1 : 0
  
  name    = "${var.project_name}-${var.environment}-budget-alerts"
  project = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project_name
  }
}

# Pub/Sub subscription for budget alerts
resource "google_pubsub_subscription" "budget_alerts" {
  count = var.enable_pubsub ? 1 : 0
  
  name    = "${var.project_name}-${var.environment}-budget-alerts-sub"
  topic   = google_pubsub_topic.budget_alerts[0].name
  project = var.project_id

  # Message retention 7 days
  message_retention_duration = "604800s"

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project_name
  }
}

# Monitoring notification channel for email alerts
resource "google_monitoring_notification_channel" "email" {
  count = length(var.alert_emails)
  
  display_name = "Budget Alert - ${var.alert_emails[count.index]}"
  type         = "email"
  project      = var.project_id
  
  labels = {
    email_address = var.alert_emails[count.index]
  }

  enabled = true
}

# Alert policy for high spend rate
resource "google_monitoring_alert_policy" "cost_spike" {
  count = var.enable_cost_spike_alerts ? 1 : 0
  
  display_name = "${var.project_name}-${var.environment}-cost-spike-alert"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "Cost spike detected"
    
    condition_threshold {
      filter          = "resource.type = \"global\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.cost_spike_threshold
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id

  alert_strategy {
    auto_close = "604800s" # 7 days
  }

  documentation {
    content   = <<-EOT
      ## Cost Spike Alert
      
      The project spending rate has exceeded the configured threshold.
      
      **Action Required:**
      1. Review current running resources in GCP Console
      2. Check for unexpected resource creation
      3. Verify autoscaling policies
      4. Review recent deployments
      
      **Common Causes:**
      - Unintended resource deployment
      - Autoscaling responding to traffic spike
      - Long-running batch jobs
      - Data egress charges
      
      **Billing Dashboard:** https://console.cloud.google.com/billing
    EOT
    mime_type = "text/markdown"
  }
}
