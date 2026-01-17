resource "aws_cloudwatch_log_group" "items_api" {
  name              = "/items-api"
  retention_in_days = 7
}
