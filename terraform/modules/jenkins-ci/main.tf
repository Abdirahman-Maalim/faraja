resource "aws_iam_user" "jenkins" {
  name = "jenkins-ci"
}

resource "aws_iam_user_policy" "ecr_push" {
  name = "ecr-push-faraja"
  user = aws_iam_user.jenkins.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
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
      }
    ]
  })
}
