# Fetch the GitHub OIDC certificate dynamically to prevent hardcoded thumbprint expiration
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 1. The Trust Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# 2. The IAM Role
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Using StringLike allows us to bypass strict case/environment suffix mismatches
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:*Otchere/terraform-ecs-deployment:*"
          }
        }
      }
    ]
  })
}

# 3. The Permissions (Scoped down to necessary Terraform operations)
resource "aws_iam_role_policy" "terraform_deploy_policy" {
  name = "terraform-ecs-deploy-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Required for VPC, Subnets, Security Groups, and Internet Gateways
          "ec2:*",
          # Required for ECS Cluster, Task Definitions, and Services
          "ecs:*",
          # Required for managing the Terraform state file
          "s3:*",
          # Required to pass roles to ECS tasks (if task execution roles are added later)
          "iam:PassRole",
          # Required to write container logs to CloudWatch
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 4. The Output
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "Copy this ARN into your GitHub Actions YAML file"
}