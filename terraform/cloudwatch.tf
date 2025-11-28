# ============================================================================
# CloudWatch Container Insights and Monitoring
# ============================================================================

resource "aws_cloudwatch_log_group" "container_insights" {
  count = var.enable_cloudwatch_monitoring ? 1 : 0

  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Module = "CloudWatch/Container-Insights"
    }
  )
}

# CloudWatch agent for Container Insights
resource "kubernetes_namespace_v1" "amazon_cloudwatch" {
  count = var.enable_cloudwatch_monitoring ? 1 : 0

  metadata {
    name = "amazon-cloudwatch"
    labels = {
      name = "amazon-cloudwatch"
    }
  }

  depends_on = [module.eks]
}

# SNS Topic for alarms
resource "aws_sns_topic" "cloudwatch_alarms" {
  count = var.enable_cloudwatch_alarms && var.alarm_sns_topic_arn == "" ? 1 : 0

  name = "${var.cluster_name}-cloudwatch-alarms"

  tags = merge(
    local.common_tags,
    {
      Module = "CloudWatch/SNS-Topic"
    }
  )
}

# SNS Topic subscriptions
resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? length(var.alarm_email_endpoints) : 0

  topic_arn = var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : aws_sns_topic.cloudwatch_alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

locals {
  alarm_topic_arn = var.enable_cloudwatch_alarms ? (
    var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : try(aws_sns_topic.cloudwatch_alarms[0].arn, "")
  ) : ""
}

# Cluster CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "cluster_cpu_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-cluster-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS cluster CPU utilization"
  alarm_actions       = local.alarm_topic_arn != "" ? [local.alarm_topic_arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = merge(
    local.common_tags,
    {
      Module = "CloudWatch/Alarm-CPU"
    }
  )
}

# Cluster memory utilization alarm
resource "aws_cloudwatch_metric_alarm" "cluster_memory_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-cluster-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS cluster memory utilization"
  alarm_actions       = local.alarm_topic_arn != "" ? [local.alarm_topic_arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = merge(
    local.common_tags,
    {
      Module = "CloudWatch/Alarm-Memory"
    }
  )
}
