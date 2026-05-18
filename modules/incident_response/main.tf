# --- Amazon SNS Alerting Infrastructure ---
resource "aws_sns_topic" "incident_topic" {
  name = "${var.environment}-major-incident-topic"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.incident_topic.arn
  protocol  = "email"
  endpoint  = var.incident_email
}

# --- Core Lambda Execution Security Configuration ---
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.environment}-mim-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "${var.environment}-lambda-sns-publish-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.incident_topic.arn
    }]
  })
}

# --- Packaging Lambda Automation Scripts ---
data "archive_file" "chatops_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/chatops_router.py"
  output_path = "${path.module}/lambdas/chatops_router.zip"
}

resource "aws_lambda_function" "chatops_router" {
  filename         = data.archive_file.chatops_zip.output_path
  function_name    = "${var.environment}-email-diagnostic-router"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "chatops_router.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.chatops_zip.output_base64sha256

  environment {
    variables = { SNS_TOPIC_ARN = aws_sns_topic.incident_topic.arn }
  }
}

data "archive_file" "remediation_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/auto_remediation.py"
  output_path = "${path.module}/lambdas/auto_remediation.zip"
}

resource "aws_lambda_function" "auto_remediation" {
  filename         = data.archive_file.remediation_zip.output_path
  function_name    = "${var.environment}-auto-remediation"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "auto_remediation.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.remediation_zip.output_base64sha256
}

# --- Amazon EventBridge Event Topology Map ---
resource "aws_cloudwatch_event_rule" "incident_rule" {
  name        = "${var.environment}-mim-routing-rule"
  description = "Intercepts the CloudWatch Alarm state changes to ALARM"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [var.monitored_alarm_name]
      state     = { value = ["ALARM"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.incident_rule.name
  target_id = "DirectSNSAlert"
  arn       = aws_sns_topic.incident_topic.arn
}

resource "aws_cloudwatch_event_target" "chatops_target" {
  rule      = aws_cloudwatch_event_rule.incident_rule.name
  target_id = "EmailRouter"
  arn       = aws_lambda_function.chatops_router.arn
}

resource "aws_cloudwatch_event_target" "remediation_target" {
  rule      = aws_cloudwatch_event_rule.incident_rule.name
  target_id = "TriggerRemediation"
  arn       = aws_lambda_function.auto_remediation.arn
}

resource "aws_lambda_permission" "allow_eb_chatops" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatops_router.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.incident_rule.arn
}

resource "aws_lambda_permission" "allow_eb_remediation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.incident_rule.arn
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.incident_topic.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.incident_topic.arn
    }]
  })
}