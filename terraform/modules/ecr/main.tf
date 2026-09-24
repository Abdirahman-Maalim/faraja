resource "aws_ecr_repository" "backend" {
  name                 = var.backend_repo_name
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "frontend" {
  name                 = var.frontend_repo_name
  image_tag_mutability = "MUTABLE"
}
