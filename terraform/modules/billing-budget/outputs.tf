output "budget_id" {
  description = "ID of the billing budget"
  value       = google_billing_budget.project_budget.id
}

output "budget_name" {
  description = "Name of the billing budget"
  value       = google_billing_budget.project_budget.display_name
}

output "pubsub_topic_id" {
  description = "ID of the Pub/Sub topic for budget alerts"
  value       = var.enable_pubsub ? google_pubsub_topic.budget_alerts[0].id : null
}

output "pubsub_subscription_id" {
  description = "ID of the Pub/Sub subscription for budget alerts"
  value       = var.enable_pubsub ? google_pubsub_subscription.budget_alerts[0].id : null
}

output "notification_channel_ids" {
  description = "IDs of the monitoring notification channels"
  value       = google_monitoring_notification_channel.email[*].id
}

output "alert_policy_id" {
  description = "ID of the cost spike alert policy"
  value       = var.enable_cost_spike_alerts ? google_monitoring_alert_policy.cost_spike[0].id : null
}
