# Use the archive_file data source to zip the Python file before uploading to Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "./tag_creation_lambda_function.py"  # Path to your Python file
  output_path = "./tag_creation_lambda_function.zip"  # Output path for the zip file
}


provider "aws" {
  region = "ap-south-1" # Change as needed
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "EC2TaggingLambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "EC2TaggingPolicy"
  description = "Allows Lambda to tag EC2 instances"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*"
    }
  ]
}
EOF
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}



# Lambda Function (ZIP must be uploaded separately)
resource "aws_lambda_function" "ec2_tagging_lambda" {
  function_name    = "EC2AutoTagging"
  role             = aws_iam_role.lambda_role.arn
  handler          = "tag_creation_lambda_function.lambda_handler"
  runtime          = "python3.9"
  # filename         = "./tag_creation_lambda_function.zip" # Ensure this is uploaded
  filename         = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # source_code_hash = filebase64sha256("./tag_creation_lambda_function.zip")

  # Set the timeout to 15 minutes (900 seconds)
  timeout = 900
}

# EventBridge Rule to trigger Lambda on EC2 launch
resource "aws_cloudwatch_event_rule" "ec2_launch_rule" {
  name        = "EC2-Tagging-Rule"
  description = "Triggers Lambda on EC2 launch"

  event_pattern = <<EOF
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": ["RunInstances"]
  }
}
EOF
}


# Set Lambda as the target for EventBridge rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_launch_rule.name
  arn       = aws_lambda_function.ec2_tagging_lambda.arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "eventbridge_invoke_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_tagging_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_launch_rule.arn
}

