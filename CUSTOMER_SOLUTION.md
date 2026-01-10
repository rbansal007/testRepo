# Solution for "Provider produced inconsistent final plan" Error in TFE

## Problem Summary
Customer is experiencing the following error in Terraform Enterprise (TFE):

```
When expanding the plan for module.aurora_cluster.aws_cloudwatch_metric_alarm.rds_cpu_writer_crit[0] 
to include new values learned so far during apply, provider "registry.terraform.io/hashicorp/aws" 
produced an invalid new value for .alarm_description: 
was cty.StringVal("CRITICAL - demo-db-cluster-us-east-1 DB WRITER CPUUtilization >= 90%"), 
but now cty.StringVal("CRITICAL - demo-db-cluster-us-east-1 DB WRITER CPUUtilization >= 98%").
```

## Root Cause
The issue occurs when using `count` with CloudWatch alarms that have dynamic YAML-based configuration. In TFE:
- During **plan phase**: YAML lookup succeeds, returns 90
- During **apply phase**: YAML lookup fails/returns null, falls back to default 98
- This creates an inconsistency that Terraform detects

## Solution: Pre-compute ALL values in locals

The customer has already implemented `coalesce()` for thresholds, but the issue persists because:
1. They're still using `count` on the resource
2. Other parameters might still be using direct `try()` expressions

### Complete Working Solution

```hcl
locals {
  # Parse YAML alarms into a map
  alarms_yaml = try(var.custom_settings_yaml.alarms, [])
  alarms_by_name = {
    for a in local.alarms_yaml :
    a.name => {
      datapoints_to_alarm = try(tonumber(a.datapoints_to_alarm), null)
      evaluation_periods  = try(tonumber(a.evaluation_periods), null)
      period              = try(tonumber(a.period), null)
      threshold           = try(tonumber(a.threshold), null)
    }
  }

  # Pre-compute ALL alarm parameters - compute once, use everywhere
  threshold_writer_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_crit"].threshold, null),
    90
  )
  datapoints_writer_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_crit"].datapoints_to_alarm, null),
    10
  )
  evaluation_periods_writer_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_crit"].evaluation_periods, null),
    10
  )
  period_writer_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_crit"].period, null),
    60
  )
}

# IMPORTANT: Remove count if possible, or ensure it's static
resource "aws_cloudwatch_metric_alarm" "rds_cpu_writer_crit" {
  # Option 1: Remove count entirely (RECOMMENDED)
  alarm_name          = "${var.cluster_identifier}-rds_cpu_writer_crit"
  
  # Option 2: If you must use count, make it static
  # count               = 1
  
  comparison_operator = "GreaterThanOrEqualToThreshold"
  
  # Use pre-computed locals everywhere - NO direct try() or lookups
  datapoints_to_alarm = local.datapoints_writer_crit
  evaluation_periods  = local.evaluation_periods_writer_crit
  period              = local.period_writer_crit
  threshold           = local.threshold_writer_crit
  
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  statistic           = "Average"

  # Use the SAME pre-computed local in description
  alarm_description = "CRITICAL - ${var.cluster_identifier} DB WRITER CPUUtilization >= ${local.threshold_writer_crit}%"

  alarm_actions = [var.sns_critical_email]
  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
    Role                = "WRITER"
  }
}
```

## Key Points

1. **Pre-compute everything in locals** - ALL parameters should be in locals with `coalesce()`
2. **Use the SAME local variable everywhere** - Don't repeat `try()` expressions in the resource
3. **Remove `count` if possible** - If you need conditional creation, use `count = var.enable_alarm ? 1 : 0` with a static variable
4. **Never use `try()` directly in resource attributes** - Always go through a local variable first

## Why This Works

- Locals are evaluated once during plan phase
- The values are "baked in" and don't change during apply
- TFE can reliably track the values throughout the workflow
- No dynamic lookups happen during apply phase

## Alternative: Use for_each Instead of count

If you need multiple alarms dynamically created:

```hcl
locals {
  # Create a stable map of alarms to create
  alarms_to_create = {
    writer_crit = {
      threshold    = local.threshold_writer_crit
      datapoints   = local.datapoints_writer_crit
      eval_periods = local.evaluation_periods_writer_crit
      period       = local.period_writer_crit
      severity     = "CRITICAL"
      sns_topic    = var.sns_critical_email
    }
    # Add other alarms...
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each = local.alarms_to_create
  
  alarm_name          = "${var.cluster_identifier}-${each.key}"
  threshold           = each.value.threshold
  datapoints_to_alarm = each.value.datapoints
  # ... rest of config using each.value
}
```

This ensures stability and makes the configuration more maintainable.
