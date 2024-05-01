resource "aws_s3_bucket" "crcbucket" {
  bucket = "crcclouddevbrian"
}

resource "aws_s3_bucket_acl" "crcbucket_acl" {
  bucket = aws_s3_bucket.crcbucket.id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "crcbucket_policy" {
  bucket = aws_s3_bucket.crcbucket.bucket
  policy = jsonencode({
    Version = "2008-10-17",
    Id      = "PolicyForCloudFrontPrivateContent",
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.crcbucket.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::308372567288:distribution/E3V01VTKAIVT5Y"
          }
        }
      }
    ]
  })
}

resource "aws_dynamodb_table" "crctable" {
  name         = "crcvisits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "name"

  attribute {
    name = "name"
    type = "S"
  }
  attribute {
    name = "count"
    type = "N"
  }
  global_secondary_index {
    name            = "CountIndex"
    hash_key        = "count"
    projection_type = "ALL"
  }
}

data "archive_file" "ziplambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/function.py"
  output_path = "${path.module}/lambda/function.zip"
}

resource "aws_lambda_function" "crcvisitorcount" {
  filename         = data.archive_file.ziplambda.output_path
  source_code_hash = data.archive_file.ziplambda.output_base64sha256
  function_name    = "crcvisitorcount"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.handler"
  runtime          = "python3.8"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "crcvisitorcount-role"

  assume_role_policy = jsonencode(
    { "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Effect" : "Allow",
        }
      ]
  })
}

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "crcvisitorcount-policy"
  path        = "/"
  description = "AWS IAM Policy for Lambda"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:*:*:*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem"
          ],
          "Resource" : "arn:aws:dynamodb:*:*:table/crcvisits"
        },
      ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_lambda_function_url" "crcvisitsurl" {
  function_name      = aws_lambda_function.crcvisitorcount.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}