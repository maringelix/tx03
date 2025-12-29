# Load Balancer Module - Static IP and SSL Certificate

Manages a static global IP address and Google-managed SSL certificate for GKE Ingress.

## Features

- ✅ **Static Global IP**: Reserved external IP address for Load Balancer
- ✅ **Google-managed SSL Certificate**: Automatic creation and renewal
- ✅ **Cloud DNS Integration**: Optional automatic DNS record creation
- ✅ **Kubernetes Annotations**: Output ready for Ingress configuration

## Usage

```hcl
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_id  = var.project_id
  name_prefix = "tx03-dev"
  environment = "dev"
  
  enable_ssl = true
  domains    = ["dx03.example.com", "www.dx03.example.com"]
  
  # Optional: Cloud DNS zone for automatic DNS records
  dns_zone_name = "example-com-zone"
  
  labels = {
    environment = "dev"
    project     = "tx03"
  }
}
```

## Without Domain (HTTP only, for testing)

```hcl
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_id  = var.project_id
  name_prefix = "tx03-dev"
  environment = "dev"
  
  enable_ssl = false  # No SSL certificate
  domains    = []     # No domains needed
}
```

## Outputs

- `static_ip_address` - The IP address (e.g., "34.54.86.122")
- `static_ip_name` - Resource name for Ingress annotation
- `ssl_certificate_name` - Certificate name for Ingress annotation
- `ingress_annotations` - Complete annotations map for Kubernetes Ingress

## SSL Certificate Provisioning

⚠️ **Important:** Google-managed SSL certificates require:

1. **DNS must point to the IP FIRST** (A record)
2. **Certificate provisioning takes 15-60 minutes** after DNS is configured
3. **HTTPS will not work until certificate is ACTIVE**

Check certificate status:
```bash
gcloud compute ssl-certificates describe CERT_NAME --global
```

Status progression:
- `PROVISIONING` → DNS validation in progress (15-60 min)
- `ACTIVE` → Certificate ready, HTTPS working ✅
- `FAILED` → DNS not pointing to IP or domain unreachable

## Cost

- **Static IP**: $0.01/hour ($7.30/month) when NOT attached to running service
- **Static IP**: FREE when attached to running Load Balancer
- **SSL Certificate**: FREE (Google-managed)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| google | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| google_compute_global_address | resource |
| google_compute_managed_ssl_certificate | resource |
| google_dns_record_set | resource |
