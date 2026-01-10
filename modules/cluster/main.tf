variable "cluster_identifier" {
  description = "Database cluster identifier"
  type        = string
}

variable "sns_warning_email" {
  description = "SNS topic ARN for warning alerts"
  type        = string
}

variable "sns_critical_email" {
  description = "SNS topic ARN for critical alerts"
  type        = string
}

variable "custom_settings_yaml" {
  description = "Decoded YAML for setting configuration override"
  type        = any
  default     = {}
}

locals {
  # Read decoded YAML safely; if missing/malformed, fallback to empty set
  alarms_yaml = try(var.custom_settings_yaml.alarms, [])

  # Convert YAML list to a map keyed by alarm name with typed fields (numbers)
  alarms_by_name = {
    for a in local.alarms_yaml :
    a.name => {
      datapoints_to_alarm = try(tonumber(a.datapoints_to_alarm), null)
      evaluation_periods  = try(tonumber(a.evaluation_periods), null)
      period              = try(tonumber(a.period), null)
      threshold           = try(tonumber(a.threshold), null)
    }
  }

  # Pre-compute all threshold values with defaults using coalesce()
  # This ensures stable evaluation in TFE - computed once during plan phase
  # If YAML provides a value, use it; otherwise fall back to the default
  threshold_writer_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_crit"].threshold, null),
    90 # Default when not in YAML
  )
  threshold_writer_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_warn"].threshold, null),
    88 # Default when not in YAML
  )
  threshold_reader_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_crit"].threshold, null),
    95 # Default when not in YAML
  )
  threshold_reader_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_warn"].threshold, null),
    77 # Default when not in YAML
  )

  # Pre-compute other alarm parameters
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

  datapoints_writer_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_warn"].datapoints_to_alarm, null),
    5
  )
  evaluation_periods_writer_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_warn"].evaluation_periods, null),
    10
  )
  period_writer_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_writer_warn"].period, null),
    60
  )

  datapoints_reader_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_crit"].datapoints_to_alarm, null),
    10
  )
  evaluation_periods_reader_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_crit"].evaluation_periods, null),
    10
  )
  period_reader_crit = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_crit"].period, null),
    60
  )

  datapoints_reader_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_warn"].datapoints_to_alarm, null),
    5
  )
  evaluation_periods_reader_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_warn"].evaluation_periods, null),
    10
  )
  period_reader_warn = coalesce(
    try(local.alarms_by_name["rds_cpu_reader_warn"].period, null),
    60
  )
}

# PROBLEMATIC VERSION - This will fail with inconsistent plan error
# because default (98) doesn't match YAML value (90)
resource "aws_cloudwatch_metric_alarm" "rds_cpu_writer_crit_broken" {
  count               = 0 # Disabled to show the issue
  alarm_name          = "${var.cluster_identifier}-rds_cpu_writer_crit-broken"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = try(local.alarms_by_name["rds_cpu_writer_crit"].datapoints_to_alarm, 10)
  evaluation_periods  = try(local.alarms_by_name["rds_cpu_writer_crit"].evaluation_periods, 10)
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = try(local.alarms_by_name["rds_cpu_writer_crit"].period, 60)
  statistic           = "Average"
  threshold           = try(local.alarms_by_name["rds_cpu_writer_crit"].threshold, 98) # WRONG: 98 doesn't match YAML (90)

  alarm_description = "CRITICAL - ${var.cluster_identifier} DB WRITER CPUUtilization >= ${try(local.alarms_by_name["rds_cpu_writer_crit"].threshold, 98)}%"

  alarm_actions = [var.sns_critical_email]
  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
    Role                = "WRITER"
  }
}

# TFE-COMPATIBLE VERSION - Uses pre-computed locals for stable evaluation
# Temporarily commented out due to IAM permission constraints
# Uncommented to test customer scenario, but requires cloudwatch:PutMetricAlarm permission
# resource "aws_cloudwatch_metric_alarm" "rds_cpu_writer_crit" {
#   count               = 1  # Customer is using count, which can cause issues with dynamic lookups
#   alarm_name          = "${var.cluster_identifier}-rds_cpu_writer_crit"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   datapoints_to_alarm = local.datapoints_writer_crit
#   evaluation_periods  = local.evaluation_periods_writer_crit
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/RDS"
#   period              = local.period_writer_crit
#   statistic           = "Average"
#   threshold           = local.threshold_writer_crit
#
#   alarm_description = "CRITICAL - ${var.cluster_identifier} DB WRITER CPUUtilization >= ${local.threshold_writer_crit}%"
#
#   alarm_actions = [var.sns_critical_email]
#   dimensions = {
#     DBClusterIdentifier = var.cluster_identifier
#     Role                = "WRITER"
#   }
# }

resource "aws_cloudwatch_metric_alarm" "rds_cpu_writer_warn" {
  count               = 1
  alarm_name          = "${var.cluster_identifier}-rds_cpu_writer_warn"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = local.datapoints_writer_warn
  evaluation_periods  = local.evaluation_periods_writer_warn
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = local.period_writer_warn
  statistic           = "Average"
  threshold           = local.threshold_writer_warn

  alarm_description = "WARNING - ${var.cluster_identifier} DB WRITER CPUUtilization >= ${local.threshold_writer_warn}%"

  alarm_actions = [var.sns_warning_email]
  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
    Role                = "WRITER"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_reader_crit" {
  count               = 1
  alarm_name          = "${var.cluster_identifier}-rds_cpu_reader_crit"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = local.datapoints_reader_crit
  evaluation_periods  = local.evaluation_periods_reader_crit
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = local.period_reader_crit
  statistic           = "Average"
  threshold           = local.threshold_reader_crit

  alarm_description = "CRITICAL - ${var.cluster_identifier} DB READER CPUUtilization >= ${local.threshold_reader_crit}%"

  alarm_actions = [var.sns_critical_email]
  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
    Role                = "READER"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_reader_warn" {
  count               = 1
  alarm_name          = "${var.cluster_identifier}-rds_cpu_reader_warn"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = local.datapoints_reader_warn
  evaluation_periods  = local.evaluation_periods_reader_warn
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = local.period_reader_warn
  statistic           = "Average"
  threshold           = local.threshold_reader_warn

  alarm_description = "WARNING - ${var.cluster_identifier} DB READER CPUUtilization >= ${local.threshold_reader_warn}%"

  alarm_actions = [var.sns_warning_email]
  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
    Role                = "READER"
  }
}

# Test resource to verify YAML configuration loading
resource "local_file" "alarm_config_test" {
  filename = "${path.module}/alarm_config_output.txt"
  content  = <<-EOT
    Alarm Configuration Test Results
    =================================
    Generated at: ${timestamp()}
    
    Cluster: ${var.cluster_identifier}
    
    YAML Configuration Loaded:
    ${jsonencode(var.custom_settings_yaml)}
    
    Computed Alarm Thresholds:
    --------------------------
    Writer Critical: ${local.threshold_writer_crit}% (datapoints: ${local.datapoints_writer_crit}, evaluation: ${local.evaluation_periods_writer_crit}, period: ${local.period_writer_crit}s)
    Writer Warning:  ${local.threshold_writer_warn}% (datapoints: ${local.datapoints_writer_warn}, evaluation: ${local.evaluation_periods_writer_warn}, period: ${local.period_writer_warn}s)
    Reader Critical: ${local.threshold_reader_crit}% (datapoints: ${local.datapoints_reader_crit}, evaluation: ${local.evaluation_periods_reader_crit}, period: ${local.period_reader_crit}s)
    Reader Warning:  ${local.threshold_reader_warn}% (datapoints: ${local.datapoints_reader_warn}, evaluation: ${local.evaluation_periods_reader_warn}, period: ${local.period_reader_warn}s)
    
    SNS Topics:
    -----------
    Critical: ${var.sns_critical_email}
    Warning:  ${var.sns_warning_email}
  EOT
}
