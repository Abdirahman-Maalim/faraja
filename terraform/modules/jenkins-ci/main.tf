locals {
  source_ip_condition = length(var.allowed_source_cidrs) > 0 ? {
    Condition = { IpAddress = { "aws:SourceIp" = var.allowed_source_cidrs } }
  } : {}
}

resource "aws_iam_user" "jenkins" {
  name = "jenkins-ci"
}
resource "aws_iam_user_policy" "ecr_push" {
  name = "ecr-push-faraja"
  user = aws_iam_user.jenkins.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge({
        Sid      = "EcrAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }, local.source_ip_condition),
      merge({
        Sid    = "PushToFarajaReposOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = var.repository_arns
      }, local.source_ip_condition)
    ]
  })
}
