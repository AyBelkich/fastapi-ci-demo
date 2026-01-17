data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_logs" {
  name               = "items-api-ec2-logs"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_logs" {
  name   = "items-api-logs"
  role   = aws_iam_role.ec2_logs.id
  policy = data.aws_iam_policy_document.ec2_logs_policy.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "items-api-instance-profile"
  role = aws_iam_role.ec2_logs.name
}
