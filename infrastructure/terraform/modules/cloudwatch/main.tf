resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EKS", "cluster_failed_node_count", "ClusterName", var.cluster_name]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "EKS Failed Node Count"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${var.project_name}-db"]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "RDS CPU Utilization"
        }
      }
    ]
  })
}
