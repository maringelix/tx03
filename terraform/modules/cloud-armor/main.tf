# Cloud Armor Security Policy
resource "google_compute_security_policy" "policy" {
  name        = var.policy_name
  project     = var.project_id
  description = "Cloud Armor WAF policy for ${var.project_name}"

  # Default rule: Allow by default, block specific threats
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule: allow all traffic"
  }

  # Block SQL Injection attempts
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block SQL Injection attempts (OWASP A03:2021)"
  }

  # Block XSS attacks
  rule {
    action   = "deny(403)"
    priority = "1001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block Cross-Site Scripting attacks (OWASP A03:2021)"
  }

  # Block Local File Inclusion (LFI) attacks
  rule {
    action   = "deny(403)"
    priority = "1002"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Block Local File Inclusion attacks"
  }

  # Block Remote File Inclusion (RFI) attacks
  rule {
    action   = "deny(403)"
    priority = "1003"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-stable')"
      }
    }
    description = "Block Remote File Inclusion attacks"
  }

  # Block Remote Code Execution (RCE) attempts
  rule {
    action   = "deny(403)"
    priority = "1004"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }
    description = "Block Remote Code Execution attempts (OWASP A03:2021)"
  }

  # Block Scanner/Bot traffic
  rule {
    action   = "deny(403)"
    priority = "1005"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-stable')"
      }
    }
    description = "Block known scanner/bot traffic"
  }

  # Block Protocol attacks
  rule {
    action   = "deny(403)"
    priority = "1006"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-stable')"
      }
    }
    description = "Block protocol attacks"
  }

  # Block PHP injection attacks
  rule {
    action   = "deny(403)"
    priority = "1007"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('php-stable')"
      }
    }
    description = "Block PHP injection attacks"
  }

  # Block Session Fixation attacks
  rule {
    action   = "deny(403)"
    priority = "1008"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sessionfixation-stable')"
      }
    }
    description = "Block Session Fixation attacks"
  }

  # Rate limiting rule (optional)
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = "2000"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        enforce_on_key = "IP"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = 60
        }
        ban_duration_sec = var.ban_duration_sec
      }
      description = "Rate limiting: ${var.rate_limit_threshold} requests per minute per IP"
    }
  }

  # Adaptive protection (DDoS)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = var.enable_adaptive_protection
    }
  }
}
