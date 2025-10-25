# Grafana Alerting Module for Platform Apps

This Terraform module sets up comprehensive alerting for Platform applications in Grafana, implementing the **4 Golden Signals** of monitoring:

1. **Latency** - How long it takes to service a request
2. **Traffic** - How much demand is placed on the system
3. **Errors** - Rate of requests that fail
4. **Saturation** - How "full" the service is

## Features

✅ **9 Alert Rules per Application** covering all 4 golden signals  
✅ **Slack Integration** for real-time notifications  
✅ **Customizable Thresholds** for each metric  
✅ **Smart Grouping** and deduplication  
✅ **Rich Alert Messages** with context and runbook links  
✅ **Namespace Isolation** - only alerts from platform apps  

## Alert Rules Created

### 🚀 Latency (2 rules per app)
- **High P95 Latency** - Warning when P95 > 1s
- **Critical P99 Latency** - Critical when P99 > 3s

### 📊 Traffic (1 rule per app)
- **Traffic Drop** - Warning when traffic drops >50% vs 1 hour ago

### ❌ Errors (2 rules per app)
- **High 5xx Error Rate** - Critical when >5% server errors
- **High 4xx Error Rate** - Warning when >10% client errors

### 💾 Saturation (4 rules per app)
- **High CPU Usage** - Warning when >80% CPU
- **High Memory Usage** - Warning when >85% memory
- **Pods Not Ready** - Critical when <50% pods ready
- **Frequent Pod Restarts** - Warning when >3 restarts in 10min

## Prerequisites

### 1. Grafana Service Account Token

You need to create a service account in Grafana with the appropriate permissions:

```bash
# In Grafana UI:
# 1. Go to Administration → Service Accounts
# 2. Click "Add service account"
# 3. Name: "terraform-alerting"
# 4. Role: "Admin" (or Editor with alert rule permissions)
# 5. Click "Add service account token"
# 6. Copy the token securely
```

### 2. Slack Webhook URL

Create a Slack incoming webhook:

```bash
# 1. Go to https://api.slack.com/apps
# 2. Create a new app or select existing
# 3. Enable "Incoming Webhooks"
# 4. Add new webhook to your desired channel
# 5. Copy the webhook URL
```

### 3. Prometheus Metrics

Your platform apps must expose these metrics:
- `http_request_duration_seconds_bucket` - Request latency histogram
- `http_requests_total{status="..."}` - Request counter with status labels

## Usage

### Add to main.tf

```hcl
module "grafana_alerting" {
  source = "./modules/grafana-alerting"

  grafana_url  = "https://${var.grafana_domain}"
  grafana_auth = var.grafana_service_account_token

  slack_webhook_url = var.slack_webhook_url
  slack_channel     = "#platform-alerts"

  platform_namespace = "platform"
  platform_apps      = var.platform_apps

  # Optional: Customize thresholds
  alert_thresholds = {
    latency = {
      p95_ms       = 1000  # 1 second
      p99_ms       = 3000  # 3 seconds
      duration_min = 5
    }
    errors = {
      rate_percent = 5
      duration_min = 5
    }
    saturation = {
      cpu_percent    = 80
      memory_percent = 85
      duration_min   = 10
    }
    traffic = {
      drop_percent = 50
      duration_min = 5
    }
    availability = {
      pod_ready_percent = 50
      duration_min      = 3
    }
  }
}
```

### Add Variables to variables.tf

```hcl
variable "grafana_domain" {
  description = "Domain for Grafana server"
  type        = string
  default     = "monitoring.rtmdemos.name.ng"
}

variable "platform_namespace" {
  description = "Kubernetes namespace where platform apps run"
}

variable "platform_apps" {
  description = "List of application names in the platform"
}

variable "grafana_service_account_token" {
  description = "Grafana service account token for Terraform"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for Platform alerts"
  type        = string
  sensitive   = true
}
```

### Add to terraform.tfvars

```hcl
grafana_service_account_token  = "glsa_xxxxxxxxxxxxxxxxxxxx"
  slack_webhook_url              = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"

# Optional: Customize the list of apps to monitor
# platform_apps = [
#   "storefront-app",
#   "product-service",
#   "order-service"
# ]
```

## Slack Alert Format

Alerts sent to Slack will look like:

```
🚨 High P95 Latency - storefront-app

App: storefront-app
Namespace: platform
Severity: warning

Summary: High P95 latency detected for storefront-app
Description: P95 latency for storefront-app is above 1000ms

Status: firing
Firing: 1
Resolved: 0

• storefront-app-5b98bdd86b-2p42j - P95 latency is 1250ms

[View in Grafana]
```

## Customization

### Adjust Thresholds

Modify the `alert_thresholds` variable to suit your SLOs:

```hcl
alert_thresholds = {
  latency = {
    p95_ms       = 500   # Stricter: 500ms
    p99_ms       = 2000  # Stricter: 2s
    duration_min = 3     # Faster alert: 3 minutes
  }
  # ...
}
```

### Add More Apps

Simply add to the `platform_apps` list:

```hcl
platform_apps = [
  "platform-cms",
  "new-app-name",
  # ...
]
```

### Change Slack Channel

```hcl
slack_channel = "#production-alerts"
```

## Deployment

```bash
# Initialize Terraform (download Grafana provider)
terraform init

# Preview changes
terraform plan

# Apply alerting configuration
terraform apply

# You should see output like:
# Apply complete! Resources: 49 added, 0 changed, 0 destroyed.
# 
# Outputs:
# 
# alert_rules_summary = {
#   "error_alerts" = {
#     "rate_4xx" = 11
#     "rate_5xx" = 11
#   }
#   "latency_alerts" = {
#     "p95" = 11
#     "p99" = 11
#   }
#   "saturation_alerts" = {
#     "cpu" = 11
#     "memory" = 11
#     "pod_not_ready" = 11
#     "pod_restarts" = 11
#   }
#   "total_rules" = 99
#   "traffic_alerts" = {
#     "drop" = 11
#   }
# }
```

## Testing Alerts

### Trigger High Latency Alert

```bash
# Add artificial latency to a service
# kubectl exec examples
kubectl exec -it <pod-name> -n platform -- sh
# Inside pod, simulate slow responses
```

### Trigger High Error Rate Alert

```bash
# Temporarily misconfigure a service to return errors
# edit deployment example
kubectl edit deployment iam-service -n platform
# Change environment variable to cause errors
```

### Trigger CPU Alert

```bash
# Install stress tool in pod and run CPU stress test
# inside pod example
kubectl exec -it <pod-name> -n platform -- sh
# stress-ng --cpu 4 --timeout 600s
```

## Troubleshooting

### No Alerts Firing

1. **Check Prometheus is scraping your apps:**
   ```bash
   # In Grafana, go to Explore
  # Query: up{namespace="platform"}
   ```

2. **Verify metrics exist:**
   ```bash
  # Query: http_requests_total{namespace="platform"}
   ```

3. **Check alert rule status:**
   - Go to Grafana → Alerting → Alert rules
  - Look for "Platform Alerts" folder
   - Check evaluation status

### Alerts Not Reaching Slack

1. **Test webhook URL:**
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test from Terraform"}' \
     YOUR_SLACK_WEBHOOK_URL
   ```

2. **Check contact point:**
   - Go to Grafana → Alerting → Contact points
  - Find "platform-slack-alerts"
  - Click "Test" button

3. **Check notification policy:**
   - Go to Grafana → Alerting → Notification policies
   - Verify routing to correct contact point

## Maintenance

### Update Alert Rules

1. Modify `main.tf` in the module
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to update

### Add New Signal

Add a new `grafana_rule_group` resource in `main.tf`:

```hcl
resource "grafana_rule_group" "custom_signal" {
  name             = "Platform Custom Signal"
  folder_uid       = grafana_folder.platform_alerts.uid
  interval_seconds = 60
  
  # Add your rules...
}
```

## Cost Considerations

- ✅ **No Additional Cost** - Uses existing Grafana/Prometheus infrastructure
- ✅ **Lightweight** - Alert rules consume minimal resources
- ⚠️ **Slack Rate Limits** - Free tier: 1 message per second

## Security

- 🔒 Service account token is marked as `sensitive`
- 🔒 Slack webhook URL is marked as `sensitive`
- 🔒 Store secrets in `terraform.tfvars` (add to `.gitignore`)
- 🔒 Consider using Terraform Cloud/Enterprise for remote state with encryption

## Related Documentation

- [Grafana Alerting Docs](https://grafana.com/docs/grafana/latest/alerting/)
- [Grafana Terraform Provider](https://registry.terraform.io/providers/grafana/grafana/latest/docs)
- [Google SRE Book - Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)

## Support

For issues or questions:
1. Check Grafana logs: `kubectl logs -n monitoring <grafana-pod>`
2. Review Terraform state: `terraform show`
3. Contact DevOps team in #devops-support
