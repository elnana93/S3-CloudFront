#############################################
# GitHub Actions OIDC Provider (one-time)
#############################################
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Trust both GitHub thumbprints (avoids intermittent OIDC failures)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

#############################################
# IAM Policy: S3 sync + CloudFront invalidation
#############################################
resource "aws_iam_policy" "github_deploy_policy" {
  name        = "GitHubActions_Deploy_ResumeSite"
  description = "Allow GitHub Actions to sync site files to S3 and invalidate CloudFront cache."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3ListBucket",
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = aws_s3_bucket.site.arn
      },
      {
        Sid    = "S3ObjectRW",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "${aws_s3_bucket.site.arn}/*"
      },
      {
        Sid    = "CloudFrontInvalidate",
        Effect = "Allow",
        Action = [
          "cloudfront:CreateInvalidation"
        ],
        Resource = aws_cloudfront_distribution.site.arn
      }, 
      #############################################
      # Terraform backend permissions (S3 state)
      # Backend:
      # bucket = e5statefiles
      # key    = resume-s3/terraform.tfstate
      #############################################
      {
        Sid    = "TerraformStateListBucketScoped",
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "arn:${data.aws_partition.current.partition}:s3:::e5statefiles",
        Condition = {
          StringLike = {
            "s3:prefix" = ["resume-s3/terraform.tfstate"]
          }
        }
      },
      {
        Sid    = "TerraformStateReadExactObject",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = "arn:${data.aws_partition.current.partition}:s3:::e5statefiles/resume-s3/terraform.tfstate"
      },




      #############################################
      # Terraform backend permissions (DynamoDB lock table)
      # dynamodb_table = e5statefiles-locks
      #############################################
      {
        Sid    = "TerraformStateDynamoDBLock",
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Resource = "arn:${data.aws_partition.current.partition}:dynamodb:us-west-2:${data.aws_caller_identity.current.account_id}:table/e5statefiles-locks"
      }

      
    ]
  })
}

#############################################
# IAM Role: Trust only YOUR repo + branch
#############################################
resource "aws_iam_role" "github_actions_deploy_role" {
  name = "GitHubActions_Deploy_ResumeSite"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            # Only allow deployments from this repo + main branch:
            "token.actions.githubusercontent.com:sub" = "repo:elnana93/S3-CloudFront:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_deploy_attach" {
  role       = aws_iam_role.github_actions_deploy_role.name
  policy_arn = aws_iam_policy.github_deploy_policy.arn
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_deploy_role.arn
  description = "Put this ARN into GitHub Secrets as AWS_ROLE_ARN"
}
