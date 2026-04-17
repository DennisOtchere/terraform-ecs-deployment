# 1. The Trust Provider
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Official AWS-approved thumbprints for GitHub Actions OIDC
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
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
            "token.actions.githubusercontent.com:sub" = "repo:DennisOtchere/terraform-ecs-deployment:environment:dev"
          }
        }
      }
    ]
  })
}

# 3. The Permissions
resource "aws_iam_role_policy" "terraform_deploy_policy" {
  name = "terraform-ecs-deploy-policy"

  # Attaches this policy to the role we just fixed
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Required for Terraform State Backend
          "s3:*",
          "dynamodb:*",

          # Required for Infrastructure Provisioning
          "ec2:*",
          "ecs:*",
          "logs:*",
          "elasticloadbalancing:*",

          # Required for ECS Task Roles
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:*OpenIDConnectProvider*",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListInstanceProfilesForRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies"
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
