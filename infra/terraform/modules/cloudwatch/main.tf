resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      # --- ROW 1: ALB Performance ---
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            [{ "expression": "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"RequestCount\"', 'Sum', 300)", "id": "e1", "label": "Requests" }]
          ]
          region = "ap-south-1"
          title  = "ALB: Total Request Count (Search)"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            [{ "expression": "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"TargetResponseTime\"', 'Average', 300)", "id": "e2", "label": "Latency" }]
          ]
          region = "ap-south-1"
          title  = "ALB: Target Response Time (Search)"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            [{ "expression": "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"HTTPCode_Target_5XX_Count\"', 'Sum', 300)", "id": "e3", "label": "5XX Errors" }]
          ]
          region = "ap-south-1"
          title  = "ALB: Target 5XX Errors (Search)"
          view   = "timeSeries"
          stacked = false
        }
      },
      # --- ROW 2: RDS Health ---
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = "ap-south-1"
          title  = "RDS: CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = "ap-south-1"
          title  = "RDS: Database Connections"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = "ap-south-1"
          title  = "RDS: Free Storage Space"
        }
      },
      # --- ROW 3: EKS Cluster ---
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name]
          ]
          period = 300
          stat   = "Average"
          region = "ap-south-1"
          title  = "EKS: Node CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "node_memory_utilization", "ClusterName", var.cluster_name]
          ]
          period = 300
          stat   = "Average"
          region = "ap-south-1"
          title  = "EKS: Node Memory Utilization"
        }
      }
    ]
  })
}
