terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

locals {
  acct         = var.aws_account_id
  state_bucket = "arn:aws:s3:::faraja-terraform-state-${var.aws_account_id}"
  boundary_arn = "arn:aws:iam::${var.aws_account_id}:policy/faraja-role-boundary"
  role_arn     = "arn:aws:iam::${var.aws_account_id}:role/${var.cluster_name}-*"
}
resource "aws_iam_policy" "role_boundary" {
  name = "faraja-role-boundary"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ServicesFarajaRolesMayUse"
        Effect = "Allow"
        Action = [
          "ec2:*", "elasticloadbalancing:*", "autoscaling:*", "eks:*",
          "ecr:*", "logs:*", "cloudwatch:*", "kms:CreateGrant", "kms:Describe*", "kms:Decrypt", "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid      = "ServiceLinkedRolesOnly"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_policy" "deployer" {
  name        = "faraja-terraform-deployer"
  description = "Least privilege to plan/apply/destroy the Faraja EKS stack"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "NetworkAndCompute"
        Effect    = "Allow"
        Action    = ["ec2:*"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid       = "EksAndLogs"
        Effect    = "Allow"
        Action    = ["eks:*", "logs:*", "elasticloadbalancing:Describe*", "autoscaling:Describe*"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid    = "EcrForFaraja"
        Effect = "Allow"
        Action = ["ecr:*"]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${local.acct}:repository/faraja-*"
        ]
      },
      {
        Sid      = "EcrAuthAndList"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:DescribeRepositories"]
        Resource = "*"
      },
      {
        Sid      = "TerraformStateBucket"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [local.state_bucket, "${local.state_bucket}/*"]
      },
      {
        Sid      = "TerraformLockTable"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.acct}:table/terraform-state-lock"
      },
      {
        Sid    = "ManageOnlyClusterScopedRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "iam:UntagRole", "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy"
        ]
        Resource  = local.role_arn
        Condition = { StringEquals = { "iam:PermissionsBoundary" = local.boundary_arn } }
      },
      {
        Sid      = "ReadRolesAndPolicies"
        Effect   = "Allow"
        Action   = ["iam:Get*", "iam:List*"]
        Resource = "*"
      },
      {
        Sid       = "PassClusterRolesToEksAndEc2"
        Effect    = "Allow"
        Action    = ["iam:PassRole"]
        Resource  = local.role_arn
        Condition = { StringEquals = { "iam:PassedToService" = ["eks.amazonaws.com", "ec2.amazonaws.com"] } }
      },
      {
        Sid    = "IrsaOidcProviderAndJenkinsUser"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
          "iam:CreateUser", "iam:DeleteUser", "iam:PutUserPolicy", "iam:DeleteUserPolicy", "iam:TagUser"
        ]
        Resource = [
          "arn:aws:iam::${local.acct}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/*",
          "arn:aws:iam::${local.acct}:user/jenkins-ci"
        ]
      },
      {
        Sid       = "ServiceLinkedRoles"
        Effect    = "Allow"
        Action    = ["iam:CreateServiceLinkedRole"]
        Resource  = "*"
        Condition = { StringLike = { "iam:AWSServiceName" = ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com", "autoscaling.amazonaws.com", "elasticloadbalancing.amazonaws.com"] } }
      },
      {
        Sid    = "CannotTamperWithGuardrails"
        Effect = "Deny"
        Action = [
          "iam:DeleteRolePermissionsBoundary", "iam:PutRolePermissionsBoundary",
          "iam:CreatePolicyVersion", "iam:DeletePolicy", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "deployer" {
  user       = var.deployer_user_name
  policy_arn = aws_iam_policy.deployer.arn
}
