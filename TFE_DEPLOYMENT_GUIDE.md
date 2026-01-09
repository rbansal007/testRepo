# Terraform Enterprise Deployment Guide

## What Changed

The code has been refactored to prevent "Provider produced inconsistent final plan" errors in TFE by:

1. **Pre-computing all threshold values** using `coalesce()` in locals
2. **Single evaluation during plan phase** - prevents value changes between plan and apply
3. **Maintaining flexibility** - users can still override defaults via YAML

### Key Pattern:
```hcl
locals {
  # Pre-computed value - evaluated once during plan
  threshold_writer_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_crit"].threshold, null),
    90  # Default when not in YAML
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_writer_crit" {
  threshold = local.threshold_writer_crit
  alarm_description = "... >= ${local.threshold_writer_crit}%"  # Same value
}
```

---

## How to Deploy to Terraform Enterprise

### Option 1: VCS-Driven Workflow (Recommended)

#### Step 1: Push Code to Git Repository
```bash
cd /Users/ramitbansal/Documents/samplecode
git init
git add .
git commit -m "Add TFE-compatible CloudWatch alarms with YAML overrides"
git remote add origin <your-git-repo-url>
git push -u origin main
```

#### Step 2: Create TFE Workspace
1. Log in to your Terraform Enterprise instance
2. Navigate to your organization
3. Click **"New Workspace"**
4. Select **"Version control workflow"**
5. Choose your VCS provider (GitHub, GitLab, Bitbucket, etc.)
6. Select the repository you just pushed to
7. Name your workspace (e.g., `rds-cloudwatch-alarms`)
8. Click **"Create workspace"**

#### Step 3: Configure Workspace Variables
In your TFE workspace, go to **Variables** tab and set:

**Terraform Variables:**
```
cluster_identifier       = "demo-db-cluster-us-east-1"
sns_warning_email        = "arn:aws:sns:us-east-1:123456789012:warning-topic"
sns_critical_email       = "arn:aws:sns:us-east-1:123456789012:critical-topic"
s3_uri_artifact_custom_settings_yaml = "s3://your-bucket/path/to/custom-settings.yaml"
```

**Environment Variables:**
```
AWS_ACCESS_KEY_ID        = <your-aws-access-key>        (Sensitive)
AWS_SECRET_ACCESS_KEY    = <your-aws-secret-key>        (Sensitive)
AWS_DEFAULT_REGION       = ap-south-1
```

#### Step 4: Upload custom-settings.yaml
Since TFE can't access local files, you have two options:

**Option A: Use S3 (Recommended for production)**
```bash
# Upload YAML to S3
aws s3 cp custom-settings.yaml s3://your-bucket/config/custom-settings.yaml

# Update main.tf to use S3 data source
```

**Option B: Inline the YAML in TFE variable**
Set a Terraform variable:
```hcl
variable "custom_settings_inline" {
  type = object({
    alarms = list(object({
      name                = string
      threshold           = string
      datapoints_to_alarm = string
      evaluation_periods  = string
      period              = string
    }))
  })
  default = {
    alarms = [
      {
        name                = "rds_cpu_writer_crit"
        threshold           = "90"
        datapoints_to_alarm = "10"
        evaluation_periods  = "10"
        period              = "60"
      },
      # ... other alarms
    ]
  }
}
```

#### Step 5: Trigger Run
1. In TFE workspace, click **"Actions"** → **"Start new run"**
2. Choose **"Plan and apply"**
3. Review the plan output
4. If plan looks good, click **"Confirm & Apply"**

---

### Option 2: CLI-Driven Workflow

#### Step 1: Configure TFE Backend
Update `main.tf`:
```hcl
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"  # Or your TFE hostname
    organization = "your-org-name"

    workspaces {
      name = "rds-cloudwatch-alarms"
    }
  }
}
```

#### Step 2: Authenticate
```bash
# Set your TFE token
export TF_TOKEN_app_terraform_io="your-tfe-token"

# Or use terraform login
terraform login app.terraform.io
```

#### Step 3: Initialize and Apply
```bash
cd /Users/ramitbansal/Documents/samplecode

# Initialize with TFE backend
terraform init

# Run plan
terraform plan

# Apply changes
terraform apply
```

---

### Option 3: API-Driven Workflow

```bash
# Create a new configuration version
curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  https://app.terraform.io/api/v2/workspaces/ws-xxxxx/configuration-versions

# Upload configuration files
tar -czf content.tar.gz -C /Users/ramitbansal/Documents/samplecode .

curl \
  --header "Content-Type: application/octet-stream" \
  --request PUT \
  --data-binary @content.tar.gz \
  https://archivist.terraform.io/v1/object/<upload-url>

# Trigger run
curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{"data":{"type":"runs"}}' \
  https://app.terraform.io/api/v2/workspaces/ws-xxxxx/runs
```

---

## Testing the Fix

### Local Testing First
```bash
cd /Users/ramitbansal/Documents/samplecode

# Test with YAML file present
export TF_VAR_s3_uri_artifact_custom_settings_yaml="dummy"
terraform init
terraform plan
terraform apply

# Verify output shows correct values from YAML
terraform output custom_settings_loaded
```

### Verify in TFE
After deploying to TFE:
1. Check the plan output - values should be stable
2. Apply should succeed without "inconsistent plan" errors
3. Verify alarm thresholds match YAML values

---

## How Users Override Values

Users can override any alarm parameter in their `custom-settings.yaml`:

```yaml
alarms:
  - name: "rds_cpu_writer_crit"
    threshold: "95"              # Override default (90) → will use 95
    datapoints_to_alarm: "15"    # Override default (10) → will use 15
  
  - name: "rds_cpu_writer_warn"
    threshold: "85"              # Override default (88) → will use 85
    # period not specified → will use default (60)
```

**Important:** The defaults in the code are only fallbacks when values are NOT in YAML.

---

## Troubleshooting

### Error: "Provider produced inconsistent final plan"
- **Cause:** Using inline `try()` in resource attributes
- **Fix:** Already applied - now using pre-computed locals

### Error: "Data source not found"
- **Cause:** TFE can't access local files
- **Fix:** Upload YAML to S3 or use inline variables

### Error: "Invalid YAML format"
- **Cause:** YAML parsing failed
- **Fix:** Validate YAML syntax with `yamllint custom-settings.yaml`

### Plan shows different values than YAML
- **Check:** Verify YAML is being loaded correctly
- **Debug:** Add output to show parsed YAML
  ```hcl
  output "debug_alarms" {
    value = local.alarms_by_name
  }
  ```

---

## Best Practices for TFE

1. ✅ **Use VCS workflow** for team collaboration
2. ✅ **Store sensitive values** in TFE workspace variables (marked sensitive)
3. ✅ **Use S3 for YAML files** instead of local files
4. ✅ **Enable speculative plans** on pull requests
5. ✅ **Set up notifications** for apply failures
6. ✅ **Use workspace-specific variables** for environment differences
7. ✅ **Enable cost estimation** to track infrastructure costs

---

## Additional Resources

- [TFE Workspaces Documentation](https://www.terraform.io/docs/cloud/workspaces)
- [VCS Integration Guide](https://www.terraform.io/docs/cloud/vcs)
- [Terraform CLI Configuration](https://www.terraform.io/docs/cli/config/config-file.html)
