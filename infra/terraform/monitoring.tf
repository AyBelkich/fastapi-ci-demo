resource "aws_sns_topic" "alerts" {
  name = "items-api-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "items-api-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Average"
  threshold   = 50

  dimensions = {
    InstanceId = aws_instance.api.id
  }

  alarm_description = "CPU > 50% for 2 minutes on items-api instance"

  alarm_actions = var.alarm_email == "" ? [] : [aws_sns_topic.alerts.arn]
  ok_actions    = var.alarm_email == "" ? [] : [aws_sns_topic.alerts.arn]
}
